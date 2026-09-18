require 'money'

Money::Currency.register({
  priority: 1,
  iso_code: "IDR",
  name: "Indonesian Rupiah",
  symbol: "Rp",
  disambiguate_symbol: "Rp",
  subunit: "Rupiah",
  subunit_to_unit: 1,
  thousands_separator: ".",
  decimal_mark: ","
})
Money.default_currency = Money::Currency.new("IDR")
Money.locale_backend = nil
Money.rounding_mode = BigDecimal::ROUND_HALF_UP
