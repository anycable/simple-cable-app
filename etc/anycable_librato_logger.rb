module MetricsFormatter
  def self.call(data)
    parts = []

    data.each do |key, value|
      parts << "#{key}=#{value}"
    end

    "source=ANYCABLE sample##{parts.join(' ')}"
  end
end
