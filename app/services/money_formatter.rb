class MoneyFormatter
  def self.call(cents, currency)
    return if cents.blank?

    amount = cents.to_i / 100
    unit = currency.presence || "$"
    "#{unit} #{amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
  end
end
