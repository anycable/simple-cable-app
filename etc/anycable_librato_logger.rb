module MetricsFormatter
  def self.call(data)
    parts = []

    data.each do |key, value|
      parts << "anycable.#{key}=#{value}"
    end

    "source=ANYCABLE sample##{parts.join(' ')}"
  end
end
