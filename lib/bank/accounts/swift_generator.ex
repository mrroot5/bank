defmodule Bank.Accounts.SWIFTGenerator do
  @moduledoc """
  Generate simulated SWIFT/BIC codes for a Spanish bank issuer.
  """

  @country_code "ES"

  @spec generate(keyword()) :: String.t()
  def generate(opts \\ []) do
    location_code = opts[:location_code] || random_alnum(2)
    bank_code = "BANK"
    location = String.upcase(location_code)
    branch = opts[:branch_code] || "XXX"

    bank_code <> @country_code <> location <> branch
  end

  #
  # Private functions
  #

  defp random_alnum(n) do
    chars =
      Enum.map(?A..?Z, &<<&1>>) ++
        Enum.map(?0..?9, &<<&1>>)

    Enum.map_join(1..n, fn _ -> Enum.random(chars) end)
  end
end
