defmodule Bank.Transactions do
  @moduledoc """
  The Transactions context.

  Handles financial transaction, state management,
  and atomic operations for maintaining data integrity.
  """

  import Ecto.Query, warn: false

  alias Bank.Ecto.Utils, as: EctoUtils
  alias Bank.Ledgers
  alias Bank.QueryComposer
  alias Bank.Repo
  alias Bank.Transactions.Transaction
  alias Ecto.Changeset
  alias Ecto.Schema

  @doc """
  Returns the list of transactions.
  """
  @spec list(keyword()) :: [Schema.t()]
  def list(opts \\ []) do
    Transaction
    |> QueryComposer.compose(opts[:filters])
    |> QueryComposer.filter_by_date_range(opts)
    |> order_by(^(opts[:order_by] || [desc: :updated_at]))
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
  Get by whatever field you want
  """
  @spec get_by(map() | keyword(), keyword()) :: Schema.t()
  def get_by(clauses, opts \\ []) do
    Transaction
    |> QueryComposer.maybe_preload(opts[:preload])
    |> Repo.get_by(clauses)
  end

  @doc """
  Creates a transaction with support.
  """
  @spec create(map()) :: EctoUtils.write()
  def create(attrs \\ %{}) do
    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Completes a transaction.
  """
  @spec complete(Schema.t(), map()) ::
          {:ok, transaction :: Schema.t(), ledger :: Schema.t(), account :: Schema.t()}
          | {:error, Changeset.t()}
  def complete(
        %Transaction{} = transaction,
        metadata \\ %{}
      ) do
    Repo.transact(fn ->
      transaction_result =
        transaction
        |> Transaction.complete_changeset(metadata)
        |> Repo.update()

      ledger_attrs = %{
        account_id: transaction.account_id,
        amount: transaction.amount,
        entry_type: infer_ledger_entry_type(transaction.transaction_type),
        transaction_id: transaction.id
      }

      with {:ok, updated_transaction} <- transaction_result,
           {:ok, {ledger, account}} <- Ledgers.create(ledger_attrs) do
        {:ok, {updated_transaction, ledger, account}}
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

  @spec infer_ledger_entry_type(atom()) :: :credit | :debit
  defp infer_ledger_entry_type(transaction_types)
       when transaction_types in [:deposit, :interest_payment],
       do: :credit

  defp infer_ledger_entry_type(_transaction_types), do: :debit
end
