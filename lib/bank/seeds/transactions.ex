defmodule Bank.Seeds.Transactions do
  @moduledoc """
  Seed helpers for transactions.
  """

  import Ecto.Query, only: [from: 2]

  require Logger
  alias Bank.Accounts.Account
  alias Bank.Repo
  alias Bank.Transactions
  alias Bank.Transactions.Transaction

  @transaction_types ~w(deposit withdrawal transfer fee_charge interest_payment)a

  @doc """
  Seeds transactions unless the transactions table is already populated.
  Pass force: true to always seed, even if transactions exist.
  """
  def seed(count, opts \\ []) do
    force = Keyword.get(opts, :force, false)

    if !force and transactions_exist?() do
      IO.puts("Transactions table already populated. Skipping transaction seeding.")
      :ok
    else
      IO.puts("Seeding \\#{count} transactions...")
      accounts = Repo.all(Account)

      if accounts == [] do
        IO.puts("No accounts found. Please seed accounts first.")
        :error
      else
        transactions = Enum.map(1..count, &transaction_attrs(&1, accounts))

        transactions
        |> Enum.chunk_every(500)
        |> Enum.each(fn chunk ->
          chunk
          |> Enum.map(&Transactions.create/1)
          |> Enum.each(fn
            {:ok, _transaction} ->
              :ok

            {:error, changeset} ->
              Logger.warning("Failed transaction with error: #{inspect(changeset.errors)}")
          end)
        end)

        IO.puts("Done seeding transactions.")
        :ok
      end
    end
  end

  # Private functions

  defp transaction_attrs(n, accounts) do
    account = Enum.at(accounts, rem(n - 1, length(accounts)))
    type = Enum.random(@transaction_types)
    amount = Decimal.new(Enum.random(1..1000))
    description = "Seeded transaction \#{n}"

    %{
      amount: amount,
      currency: account.currency,
      description: description,
      transaction_type: type,
      account_id: account.id
    }
  end

  defp transactions_exist?, do: Repo.exists?(from t in Transaction, select: 1)
end
