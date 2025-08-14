defmodule Bank.LedgersFixtures do
  @moduledoc """
  This module defines test fixtures for Ledgers.
  """

  require Ecto.Schema

  alias Bank.AccountsFixtures
  alias Bank.Ledgers.Ledger
  alias Bank.Repo
  alias Ecto.Schema

  @doc """
  Generate a ledger entry.

  ## Examples

      iex> fixture()
      %Ledger{}

      iex> fixture(%{amount: Decimal.new("250.00"), entry_type: :debit})
      %Ledger{}
  """
  @spec fixture(map()) :: Schema.t()
  def fixture(attrs \\ %{}) do
    account = get_or_create_account(attrs)

    attrs =
      Map.merge(
        %{
          account_id: account.id,
          amount: Decimal.new("100.000000"),
          entry_type: :credit,
          transaction_id: nil
        },
        attrs
      )

    # Create ledger directly in database to avoid balance update logic in tests
    # where we just need a ledger record for testing query functions
    %Ledger{}
    |> Ledger.changeset(attrs)
    |> Repo.insert!()
  end

  @spec multiple_fixture(map()) :: [Schema.t()]
  def multiple_fixture(attrs \\ %{}) do
    account = get_or_create_account(attrs)

    [
      fixture(%{
        account_id: account.id,
        amount: Decimal.new("200.000000"),
        entry_type: :credit,
        transaction_id: attrs[:transaction_id] || nil
      }),
      fixture(%{
        account_id: account.id,
        amount: Decimal.new("200.000000"),
        entry_type: :credit,
        transaction_id: attrs[:transaction_id] || nil
      }),
      fixture(%{
        account_id: account.id,
        amount: Decimal.new("10.000000"),
        entry_type: :debit,
        transaction_id: attrs[:transaction_id] || nil
      }),
      fixture(%{
        account_id: account.id,
        amount: Decimal.new("10.000000"),
        entry_type: :debit,
        transaction_id: attrs[:transaction_id] || nil
      })
    ]
  end

  @spec get_or_create_account(map()) :: Schema.t()
  defp get_or_create_account(attrs) do
    case attrs[:account_id] do
      nil ->
        AccountsFixtures.fixture()

      account_id ->
        case Repo.get(Bank.Accounts.Account, account_id) do
          nil -> AccountsFixtures.fixture()
          account -> account
        end
    end
  end
end
