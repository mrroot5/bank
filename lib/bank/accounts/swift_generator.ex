defmodule Bank.Accounts.SWIFTGenerator do
  @moduledoc """
  Generate simulated SWIFT/BIC codes for a Spanish bank issuer.
  """

  @country_code "ES"

  @spec generate(keyword()) :: String.t()
  def generate(opts \\ []) do
    bank_code = "BANK"
    location = (opts[:location_code] || random_alnum(2)) |> String.upcase()
    branch = opts[:branch_code] || "XXX"

    bank_code <> @country_code <> location <> branch
  end

  defp random_alnum(n) do
    chars =
      (?A..?Z |> Enum.map(&<<&1>>)) ++
        (?0..?9 |> Enum.map(&<<&1>>))

    1..n
    |> Enum.map(fn _ -> Enum.random(chars) end)
    |> Enum.join()
  end
end
