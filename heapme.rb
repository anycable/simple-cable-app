require 'fiddle'

SIZEOF_HEAP_PAGE_HEADER_STRUCT = Fiddle::SIZEOF_VOIDP

SIZEOF_RVALUE           = 40
HEAP_PAGE_ALIGN_LOG     = 14
HEAP_PAGE_ALIGN         = 1 << HEAP_PAGE_ALIGN_LOG      # 2 ^ 14
HEAP_PAGE_ALIGN_MASK    = ~(~0 << HEAP_PAGE_ALIGN_LOG)  # Mask for getting page address
REQUIRED_SIZE_BY_MALLOC = Fiddle::SIZEOF_SIZE_T * 5     # padding needed by malloc
HEAP_PAGE_SIZE          = HEAP_PAGE_ALIGN - REQUIRED_SIZE_BY_MALLOC # Actual page size
HEAP_PAGE_OBJ_LIMIT     = (HEAP_PAGE_SIZE - SIZEOF_HEAP_PAGE_HEADER_STRUCT) / SIZEOF_RVALUE

def page_address_from_object_address object_address
  object_address & ~HEAP_PAGE_ALIGN_MASK
end

p "HEAP PAGE SIZE LIMIT: #{HEAP_PAGE_OBJ_LIMIT}"

class Page < Struct.new :address, :obj_start_address, :obj_count
  def initialize address, obj_start_address, obj_count
    super
    @live_objects = []
  end

  def add_object address
    @live_objects << address
  end

  def each_slot
    return enum_for(:each_slot) unless block_given?

    objs = @live_objects.sort

    obj_count.times do |i|
      expected = obj_start_address + (i * SIZEOF_RVALUE)
      if objs.any? && objs.first == expected
        objs.shift
        yield :full
      else
        yield :empty
      end
    end
  end
end

def page_info page_address
  limit = HEAP_PAGE_OBJ_LIMIT # Max number of objects per page

  # Pages have a header with information, so we have to take that in to account
  obj_start_address = page_address + SIZEOF_HEAP_PAGE_HEADER_STRUCT

  # If the object start address isn't evenly divisible by the size of a
  # Ruby object, we need to calculate the padding required to find the first
  # address that is divisible by SIZEOF_RVALUE
  if obj_start_address % SIZEOF_RVALUE != 0
    delta = SIZEOF_RVALUE - (obj_start_address % SIZEOF_RVALUE)
    obj_start_address += delta # Move forward to first address

    # Calculate the number of objects this page can actually hold
    limit = (HEAP_PAGE_SIZE - (obj_start_address - page_address)) / SIZEOF_RVALUE
  end

  Page.new page_address, obj_start_address, limit
end

require 'json'

# Keep track of pages
pages = {}

heap_file = ARGV[0] || 'heap.json'

File.open(heap_file) do |f|
  f.each_line do |line|
    object = JSON.load line

    # Skip roots. I don't want to cover this today :)
    if object["type"] != "ROOT"
      # The object addresses are stored as strings in base 16
      address      = object["address"].to_i(16)

      # Get the address for the page
      page_address = page_address_from_object_address(address)

      # Get the page, or make a new one
      page         = pages[page_address] ||= page_info(page_address)

      page.add_object address
    end
  end
end

require 'chunky_png'

pages = pages.values

p "TOTAl PAGES: #{pages.size}"

live_slots = 0

# We're using 2x2 pixel squares to represent objects, so the height of
# the PNG will be 2x the max number of objects, and the width will be 2x the
# number of pages
height = HEAP_PAGE_OBJ_LIMIT * 2
width = pages.size * 2

png = ChunkyPNG::Image.new(width, height, ChunkyPNG::Color::TRANSPARENT)

pages.each_with_index do |page, i|
  i = i * 2

  page.each_slot.with_index do |slot, j|
    if slot == :full
      live_slots += 1
      j = j * 2
      png[i, j] = ChunkyPNG::Color.rgba(255, 0, 0, 255)
      png[i + 1, j] = ChunkyPNG::Color.rgba(255, 0, 0, 255)
      png[i, j + 1] = ChunkyPNG::Color.rgba(255, 0, 0, 255)
      png[i + 1, j + 1] = ChunkyPNG::Color.rgba(255, 0, 0, 255)
    end
  end
end

total_slots = pages.size * HEAP_PAGE_OBJ_LIMIT
empty_slots =  total_slots - live_slots

p "TOTAL LIVE SLOTS: #{live_slots}"
p "TOTAL EMPTY SLOTS: #{empty_slots}"
p "FRAGMENTATION: #{ empty_slots / total_slots.to_f }"

# png.save('heap.png', :interlace => true)
