defmodule Bank.TransactionsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Bank.Transactions` context.
  """
  alias Bank.AccountsFixtures

  @doc """
  Generate a transaction.
  """
  def fixture(attrs \\ %{}) do
    account = AccountsFixtures.fixture()

    default_attrs = %{
      account_id: account.id,
      amount: Decimal.new("100.00"),
      currency: "EUR",
      description: "Test transaction",
      transaction_type: :deposit,
      idempotency_key: "test_key_#{:crypto.strong_rand_bytes(8) |> Base.encode64()}"
    }

    {:ok, transaction} =
      default_attrs
      |> Map.merge(attrs)
      |> Bank.Transactions.create()

    transaction
  end

  def multiple_fixture do
    account = AccountsFixtures.fixture()

    [
      fixture(%{
        account_id: account.id,
        transaction_type: :deposit,
        amount: Decimal.new("100.00"),
        description: "First deposit"
      }),
      fixture(%{
        account_id: account.id,
        transaction_type: :withdrawal,
        amount: Decimal.new("50.00"),
        description: "First withdrawal"
      }),
      fixture(%{
        account_id: account.id,
        transaction_type: :transfer,
        amount: Decimal.new("75.00"),
        description: "Transfer"
      })
    ]
  end
end
