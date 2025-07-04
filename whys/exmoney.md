# Exmoney library

As a simple bank app manage money is quite important and prevent the float precision problem the main objective
of a money library. Example:

```elixir
iex> 0.1 + 0.2
# 0.30000000000000004
```

## Some features

- [Decimal](https://hexdocs.pm/decimal/readme.html) to manage precision on Elixir.
- PostgreSQL `numeric` field to prevent the problem at database level.
- Locales with another dependency to avoid problems with separators (like "." or "," for decimal numbers).
- Multiple currencies and exchange between them.
- Integration with an Open Exchange Rates to retrieve exchange rates.

A full list could be found in [their project](https://hexdocs.pm/ex_money/readme.html#why-yet-another-money-package).

## Locales example

```elixir
iex > Money.new("1.000,99", :EUR, locale: "en") |>  Money.to_string!()
# "€1.00"
iex > Money.new("1.000,99", :EUR, locale: "es") |>  Money.to_string!()
# "€1,000.99"
```

## Source code

[GitHub](https://github.com/kipcole9/money).
