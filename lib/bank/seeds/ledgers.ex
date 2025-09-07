defmodule Bank.Seeds.Ledgers do
  @moduledoc """
  Seeds the ledgers table with sample immutable ledger entries.
  Each ledger entry must be associated with an existing account.
  Some entries will also be associated with a transaction.
  """

  alias Bank.Accounts
  alias Bank.Ledgers
  alias Bank.Transactions

  @doc """
  Seeds a number of ledger entries for existing accounts.
  Pass force: true to always seed, even if ledgers exist.
  """
  def seed(opts \\ []) do
    force = Keyword.get(opts, :force, false)

    if !force and ledgers_exist?() do
      IO.puts("Ledgers table already populated. Skipping ledger seeding.")
      :ok
    else
      IO.puts("Seeding ledgers...")
      accounts = Accounts.list()
      transactions = Transactions.list()

      Enum.each(accounts, fn account ->
        account_transactions = Enum.filter(transactions, fn t -> t.account_id == account.id end)

        # Create a credit entry
        Ledgers.create(%{
          amount: Decimal.new("100.00"),
          entry_type: :credit,
          account_id: account.id,
          transaction_id: maybe_transaction_id(account_transactions)
        })

        # Create a debit entry
        Ledgers.create(%{
          amount: Decimal.new("50.00"),
          entry_type: :debit,
          account_id: account.id,
          transaction_id: maybe_transaction_id(account_transactions)
        })
      end)

      IO.puts("Done seeding ledgers.")
      :ok
    end
  end

  defp ledgers_exist? do
    import Ecto.Query, only: [from: 2]
    alias Bank.Ledgers.Ledger
    alias Bank.Repo
    Repo.exists?(from l in Ledger, select: 1)
  end

  defp maybe_transaction_id([]), do: nil

  defp maybe_transaction_id(transactions) do
    # 50% chance to associate a transaction
    if :rand.uniform() > 0.5 do
      Enum.random(transactions).id
    else
      nil
    end
  end
end
