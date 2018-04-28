module MetricsFormatter
  def self.call(data)
    parts = []

    data.each do |key, value|
      parts << "sample##{key}=#{value}"
    end

    "source=ANYCABLE #{parts.join(' ')}"
  end
end
