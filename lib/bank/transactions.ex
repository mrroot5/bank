defmodule Bank.Transactions do
  @moduledoc """
  The Transactions context.

  Handles financial transactions with idempotency, state management,
  and atomic operations for maintaining data integrity.
  """

  import Ecto.Query, warn: false
  alias Bank.Repo
  alias Bank.Transactions.Transaction
  alias Bank.Accounts
  alias Bank.Ledgers
  alias Bank.QueryComposer

  @doc """
  Returns the list of transactions.
  """
  def list(opts \\ []) do
    Transaction
    |> QueryComposer.compose(opts)
    |> QueryComposer.filter_by_date_range(opts)
    |> order_by(^(opts[:order_by] || [desc: :inserted_at]))
    |> maybe_preload(opts[:preload])
    |> Repo.all()
  end

  @doc """
  Gets a single transaction.

  Raises `Ecto.NoResultsError` if the Transaction does not exist.
  """
  def get!(id, opts \\ []) do
    Transaction
    |> maybe_preload(opts[:preload])
    |> Repo.get!(id)
  end

  @doc """
  Gets a transaction by idempotency key.

  Returns nil if not found.
  """
  def get_by_idempotency_key(key, opts \\ []) do
    Transaction
    |> where(idempotency_key: ^key)
    |> maybe_preload(opts[:preload])
    |> Repo.one()
  end

  @doc """
  Creates a transaction with idempotency support.

  If an idempotency_key is provided and a transaction with that key exists,
  returns the existing transaction.
  """
  def create(attrs \\ %{}) do
    case Map.get(attrs, :idempotency_key) do
      nil ->
        do_create(attrs)

      key ->
        case get_by_idempotency_key(key) do
          nil -> do_create(attrs)
          existing -> {:ok, existing}
        end
    end
  end

  defp do_create(attrs) do
    # TODO create an idempotency_key automatically
    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Processes a pending transaction.

  This creates the necessary ledger entries and updates account balances.
  Must be called within a transaction for consistency.
  """
  def process(%Transaction{status: :pending} = transaction) do
    # FIXME Revisar: la entrada en ledger deberia hacer con la trasaction terminada
    Repo.transaction(fn ->
      with {:ok, _} <- update_status(transaction, :processing),
           {:ok, ledger_entries} <- create_ledger_entries(transaction),
           {:ok, _} <- update_account_balances(transaction, ledger_entries),
           {:ok, completed} <- complete(transaction) do
        completed
      else
        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

  def process(%Transaction{} = transaction),
    do: {:error, {:invalid_status, transaction.status}}

  @doc """
  Completes a transaction.
  """
  def complete(
        # TODO Una transaction finalizada deberia agregar una entrada en el ledger
        %Transaction{} = transaction,
        completed_by \\ "system",
        metadata \\ %{}
      ) do
    transaction
    |> Transaction.complete_changeset(completed_by, metadata)
    |> Repo.update()
  end

  @doc """
  Fails a transaction with reason.
  """
  def fail(%Transaction{} = transaction, reason, error_code \\ nil, metadata \\ %{}) do
    transaction
    |> Transaction.fail_changeset(reason, error_code, metadata)
    |> Repo.update()
  end

  @doc """
  Cancels a pending transaction.
  """
  def cancel(%Transaction{status: :pending} = transaction),
    do: update_status(transaction, :cancelled)

  def cancel_transaction(%Transaction{}), do: {:error, :invalid_status}

  @doc """
  Updates a transaction.

  Only certain fields can be updated based on transaction status.
  """
  def update_transaction(%Transaction{} = transaction, attrs) do
    transaction
    |> Transaction.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates transaction status.
  """
  def update_status(%Transaction{} = transaction, status) do
    update_transaction(transaction, %{status: status})
  end

  @doc """
  Executes a deposit transaction.
  """
  def deposit(account_id, amount, currency, description, opts \\ []) do
    attrs = %{
      account_id: account_id,
      amount: amount,
      currency: currency,
      description: description,
      transaction_type: :deposit,
      origin: opts[:origin] || :web,
      idempotency_key: opts[:idempotency_key],
      metadata: opts[:metadata] || %{}
    }

    with {:ok, transaction} <- create(attrs) do
      process(transaction)
    end
  end

  @doc """
  Executes a withdrawal transaction.
  """
  def withdraw(account_id, amount, currency, description, opts \\ []) do
    attrs = %{
      account_id: account_id,
      amount: amount,
      currency: currency,
      description: description,
      transaction_type: :withdrawal,
      origin: opts[:origin] || :web,
      idempotency_key: opts[:idempotency_key],
      metadata: opts[:metadata] || %{}
    }

    with {:ok, transaction} <- create(attrs) do
      process(transaction)
    end
  end

  # Private functions

  defp create_ledger_entries(%Transaction{} = transaction) do
    case transaction.transaction_type do
      :deposit ->
        Ledgers.create_ledger(%{
          account_id: transaction.account_id,
          amount: transaction.amount,
          currency: transaction.currency,
          entry_type: :credit,
          origin: :transaction,
          transaction_id: transaction.id
        })

      :withdrawal ->
        Ledgers.create_ledger(%{
          account_id: transaction.account_id,
          amount: transaction.amount,
          currency: transaction.currency,
          entry_type: :debit,
          origin: :transaction,
          transaction_id: transaction.id
        })

      :transfer ->
        {:error, :not_implemented}

      _ ->
        {:error, :unsupported_transaction_type}
    end
  end

  defp update_account_balances(%Transaction{} = transaction, _ledger_entries) do
    account = Accounts.get_account_for_update!(transaction.account_id)
    new_balance = Accounts.calculate_balance_from_ledgers(account)
    Accounts.update_balance(account, new_balance)
  end

  defp maybe_preload(query, nil), do: query
  defp maybe_preload(query, []), do: query
  defp maybe_preload(query, preloads), do: preload(query, ^preloads)
end
