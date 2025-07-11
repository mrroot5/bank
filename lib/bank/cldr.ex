defmodule Bank.Cldr do
  @moduledoc """
  Required module by ex_cldr to config how to manage locales.

  Currently we only use `Clfr.Number` because we just want to manage currencies and
  currencies are include with this provider.

  ## Example

  - Currency representation in Spain: 1.234,98 €
  - Currency representation in USA: $1,234.98
  """

  use Cldr,
    default_locale: "en",
    json_library: JSON,
    otp_app: :bank,
    providers: [Cldr.Number],
    precompile_number_formats: ["¤¤#,##0.##"]
end
