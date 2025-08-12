defmodule Bank.LedgersFixtures do
  @moduledoc """
  This module defines test fixtures for Ledgers.
  """

  import Bank.AccountsFixtures
  import Ecto.Query

  # alias Bank.Ledgers
  alias Bank.Ledgers.Ledger
  alias Bank.Repo

  @doc """
  Generate a ledger entry.

  ## Examples

      iex> ledger_fixture()
      %Ledger{}

      iex> ledger_fixture(%{amount: "250.00", entry_type: :debit})
      %Ledger{}
  """
  def ledger_fixture(attrs \\ %{}) do
    account =
      case attrs[:account_id] do
        nil ->
          account_fixture()

        account_id ->
          case Repo.get(Bank.Accounts.Account, account_id) do
            nil -> account_fixture()
            account -> account
          end
      end

    attrs =
      Map.merge(
        %{
          account_id: account.id,
          amount: "100.00",
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

  @doc """
  Generate a credit ledger entry.

  ## Examples

      iex> credit_ledger_fixture()
      %Ledger{entry_type: :credit}

      iex> credit_ledger_fixture(%{amount: "75.50"})
      %Ledger{entry_type: :credit, amount: #Decimal<75.50>}
  """
  def credit_ledger_fixture(attrs \\ %{}) do
    attrs
    |> Map.put(:entry_type, :credit)
    |> ledger_fixture()
  end

  @doc """
  Generate a debit ledger entry.

  ## Examples

      iex> debit_ledger_fixture()
      %Ledger{entry_type: :debit}

      iex> debit_ledger_fixture(%{amount: "25.75"})
      %Ledger{entry_type: :debit, amount: #Decimal<25.75>}
  """
  def debit_ledger_fixture(attrs \\ %{}) do
    attrs
    |> Map.put(:entry_type, :debit)
    |> ledger_fixture()
  end

  @doc """
  Generate a ledger entry with transaction.

  ## Examples

      iex> ledger_with_transaction_fixture()
      %Ledger{transaction_id: "..."}

      iex> ledger_with_transaction_fixture(%{entry_type: :debit})
      %Ledger{entry_type: :debit, transaction_id: "..."}
  """
  def ledger_with_transaction_fixture(attrs \\ %{}) do
    account =
      case attrs[:account_id] do
        nil ->
          account_fixture()

        account_id ->
          case Repo.get(Bank.Accounts.Account, account_id) do
            nil -> account_fixture()
            account -> account
          end
      end

    transaction =
      case attrs[:transaction_id] do
        nil ->
          Bank.TransactionsFixtures.transaction_fixture(%{account_id: account.id})

        transaction_id ->
          Bank.Repo.get!(Bank.Transactions.Transaction, transaction_id)
      end

    attrs
    |> Map.put(:account_id, account.id)
    |> Map.put(:transaction_id, transaction.id)
    |> ledger_fixture()
  end

  @doc """
  Generate multiple ledger entries for testing bulk operations.

  ## Examples

      iex> ledger_list_fixture(3)
      [%Ledger{}, %Ledger{}, %Ledger{}]

      iex> ledger_list_fixture(2, %{entry_type: :debit})
      [%Ledger{entry_type: :debit}, %Ledger{entry_type: :debit}]
  """
  def ledger_list_fixture(count, base_attrs \\ %{}) do
    account = account_fixture()

    for i <- 1..count do
      attrs =
        base_attrs
        |> Map.put(:account_id, account.id)
        |> Map.put(:amount, "#{i * 10}.00")

      ledger_fixture(attrs)
    end
  end

  @doc """
  Generate ledgers with specific time ordering for testing date ranges and ordering.

  ## Examples

      iex> time_ordered_ledgers_fixture()
      [oldest_ledger, middle_ledger, newest_ledger]
  """
  def time_ordered_ledgers_fixture(attrs \\ %{}) do
    account = account_fixture()

    base_time = ~U[2024-01-01 12:00:00Z]

    ledgers = [
      # Oldest
      attrs
      |> Map.put(:account_id, account.id)
      |> Map.put(:amount, "100.00")
      |> ledger_fixture(),

      # Middle
      attrs
      |> Map.put(:account_id, account.id)
      |> Map.put(:amount, "200.00")
      |> ledger_fixture(),

      # Newest
      attrs
      |> Map.put(:account_id, account.id)
      |> Map.put(:amount, "300.00")
      |> ledger_fixture()
    ]

    # Update timestamps to ensure proper ordering
    [oldest, middle, newest] = ledgers

    Repo.update_all(
      from(l in Ledger, where: l.id == ^oldest.id),
      set: [inserted_at: DateTime.add(base_time, -2, :day)]
    )

    Repo.update_all(
      from(l in Ledger, where: l.id == ^middle.id),
      set: [inserted_at: DateTime.add(base_time, -1, :day)]
    )

    Repo.update_all(
      from(l in Ledger, where: l.id == ^newest.id),
      set: [inserted_at: base_time]
    )

    # Return refreshed ledgers with updated timestamps
    [
      Repo.get!(Ledger, oldest.id),
      Repo.get!(Ledger, middle.id),
      Repo.get!(Ledger, newest.id)
    ]
  end

  @doc """
  Generate ledgers for balance calculation testing.

  Creates a sequence of credit and debit entries that can be used
  to test balance calculation accuracy.

  ## Examples

      iex> balance_test_ledgers_fixture()
      {account, [credit_ledger, debit_ledger, credit_ledger]}
  """
  def balance_test_ledgers_fixture do
    account = account_fixture(%{balance: "1000.00"})

    ledgers = [
      # Credit 150.00 -> Balance: 1150.00
      ledger_fixture(%{
        account_id: account.id,
        amount: "150.00",
        entry_type: :credit
      }),

      # Debit 75.50 -> Balance: 1074.50
      ledger_fixture(%{
        account_id: account.id,
        amount: "75.50",
        entry_type: :debit
      }),

      # Credit 25.25 -> Balance: 1099.75
      ledger_fixture(%{
        account_id: account.id,
        amount: "25.25",
        entry_type: :credit
      })
    ]

    {account, ledgers}
  end

  @doc """
  Generate ledgers across different accounts for testing filtering and isolation.

  ## Examples

      iex> multi_account_ledgers_fixture()
      {[account1, account2], [account1_ledgers, account2_ledgers]}
  """
  def multi_account_ledgers_fixture do
    account1 = account_fixture()
    account2 = account_fixture()

    account1_ledgers = [
      ledger_fixture(%{account_id: account1.id, amount: "100.00", entry_type: :credit}),
      ledger_fixture(%{account_id: account1.id, amount: "50.00", entry_type: :debit})
    ]

    account2_ledgers = [
      ledger_fixture(%{account_id: account2.id, amount: "200.00", entry_type: :credit}),
      ledger_fixture(%{account_id: account2.id, amount: "75.00", entry_type: :debit})
    ]

    {[account1, account2], [account1_ledgers, account2_ledgers]}
  end

  @doc """
  Generate ledger entries with high precision amounts for decimal testing.

  ## Examples

      iex> high_precision_ledgers_fixture()
      [%Ledger{amount: #Decimal<123.456789>}, ...]
  """
  def high_precision_ledgers_fixture do
    account = account_fixture()

    [
      ledger_fixture(%{
        account_id: account.id,
        amount: "123.456789",
        entry_type: :credit
      }),
      ledger_fixture(%{
        account_id: account.id,
        amount: "0.000001",
        entry_type: :debit
      }),
      ledger_fixture(%{
        account_id: account.id,
        amount: "999999.999999",
        entry_type: :credit
      })
    ]
  end
end
