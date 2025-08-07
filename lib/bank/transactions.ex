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
    |> QueryComposer.maybe_preload(opts[:preload])
    |> Repo.all()
  end

  @doc """
  Gets a single transaction.

  Raises `Ecto.NoResultsError` if the Transaction does not exist.
  """
  def get!(id, opts \\ []) do
    Transaction
    |> QueryComposer.maybe_preload(opts[:preload])
    |> Repo.get!(id)
  end

  @doc """
  Gets a transaction by idempotency key.

  Returns nil if not found.
  """
  def get_by_idempotency_key(key, opts \\ []) do
    Transaction
    |> where(idempotency_key: ^key)
    |> QueryComposer.maybe_preload(opts[:preload])
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
    # FIXME create an idempotency_key automatically
    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Completes a transaction.
  """
  def complete(
        %Transaction{} = transaction,
        completed_by \\ "system",
        metadata \\ %{}
      ) do
    Repo.transact(fn ->
      transaction_result =
        transaction
        |> Transaction.complete_changeset(completed_by, metadata)
        |> Repo.update()

      ledger_attrs = %{
        account_id: transaction.account_id,
        amount: transaction.amount,
        entry_type: Ledgers.infer_entry_type(transaction.amount),
        transaction_id: transaction.id
      }

      account = Accounts.get!(transaction.account_id)

      with {:ok, updated_transaction} <- transaction_result,
           {:ok, ledger} <- Ledgers.create_ledger(ledger_attrs),
           {:ok, updated_account} <- Accounts.update_balance(account, transaction.amount) do
        {:ok, {updated_transaction, ledger, updated_account}}
      end
    end)
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
  def update_status(%Transaction{} = transaction, status),
    do: update_transaction(transaction, %{status: status})
end
