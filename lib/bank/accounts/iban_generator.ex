defmodule Bank.Accounts.IBANGenerator do
  @moduledoc """
  Generates valid simulated Spanish IBANs (ES, 24 chars).
  """

  @country "ES"

  @spec generate(keyword()) :: String.t()
  def generate(opts \\ []) do
    bank = "2525"
    branch = opts[:branch_code] || random_digits(4)
    nat = opts[:national_check] || random_digits(2)
    account = opts[:account_number]

    bban = bank <> branch <> nat <> account
    check = compute_check_digits(@country, bban)
    @country <> check <> bban
  end

  @spec prettify(String.t()) :: String.t()
  def prettify(iban) do
    iban
    |> String.replace(~r/.{4}/, &(&1 <> " "))
    |> String.trim()
  end

  @spec random_digits(pos_integer()) :: String.t()
  defp random_digits(n) when n > 0, do: Enum.map_join(1..n, fn _ -> :rand.uniform(10) - 1 end)

  defp compute_check_digits(country, bban) do
    raw = bban <> country <> "00"
    numeric = raw |> String.graphemes() |> Enum.map(&char_to_int/1) |> Enum.join()
    rem = mod97(numeric)
    check_val = 98 - rem
    Integer.to_string(check_val) |> String.pad_leading(2, "0")
  end

  defp char_to_int(ch) do
    case ch do
      <<c>> when c in ?A..?Z -> Integer.to_string(c - 55)
      _ -> ch
    end
  end

  defp mod97(digits) do
    digits
    |> String.graphemes()
    |> Enum.chunk_every(7)
    |> Enum.reduce(0, fn chunk, acc ->
      (Integer.to_string(acc) <> Enum.join(chunk)) |> String.to_integer() |> rem(97)
    end)
  end
end
