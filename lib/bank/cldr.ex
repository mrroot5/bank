defmodule Bank.Cldr do
  use Cldr,
    default_locale: "en",
    json_library: JSON,
    otp_app: :bank,
    providers: [Cldr.Number],
    precompile_number_formats: ["¤¤#,##0.##"]
end
