module ApplicationHelper
  def format_money(cents, currency)
    MoneyFormatter.call(cents, currency)
  end
end
