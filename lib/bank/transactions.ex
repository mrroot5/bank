defmodule Bank.Transactions do
  @moduledoc """
  The Transactions context.

  Handles financial transaction, state management,
  and atomic operations for maintaining data integrity.
  """

  import Ecto.Query, warn: false

  require Logger

  alias Bank.Ecto.Utils, as: EctoUtils
  alias Bank.Ledgers
  alias Bank.QueryComposer
  alias Bank.Repo
  alias Bank.Transactions.Transaction
  alias Ecto.Changeset
  alias Ecto.Schema

  @doc """
  Completes a transaction.
  """
  @spec complete(Schema.t(), map()) ::
          {:ok, {transaction :: Schema.t(), ledger :: Schema.t(), account :: Schema.t()}}
          | {:error, Changeset.t()}
  def complete(%Transaction{} = transaction, metadata \\ %{}) do
    transact =
      Repo.transact(fn ->
        with {:ok, updated_transaction} <- update_complete(transaction, metadata),
             {:ok, {ledger, account}} <- create_ledger_entry(transaction) do
          {:ok, {updated_transaction, ledger, account}}
        end
      end)

    maybe_log(transaction.id, "Bank.Transactions.complete", transact)
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
  Fails a transaction with reason.
  """
  @spec fail(Schema.t(), String.t(), pos_integer() | nil, map()) :: EctoUtils.write()
  def fail(%Transaction{} = transaction, reason, error_code \\ nil, metadata \\ %{}) do
    maybe_log(
      transaction.id,
      "Bank.Transactions.fail",
      {:error, error_code: error_code, reason: reason}
    )

    transaction
    |> Transaction.fail_changeset(reason, error_code, metadata)
    |> Repo.update()
  end

  @doc """
  Gets a single transaction.

  Raises `Ecto.NoResultsError` if the Transaction does not exist.
  """
  @spec get!(String.t(), keyword()) :: Schema.t() | no_return()
  def get!(id, opts \\ []) do
    Transaction
    |> QueryComposer.maybe_preload(opts[:preload])
    |> Repo.get!(id)
  end

  @doc """
  Get by whatever field you want
  """
  @spec get_by(map() | keyword(), keyword()) :: Schema.t() | nil | no_return()
  def get_by(clauses, opts \\ []) do
    Transaction
    |> QueryComposer.maybe_preload(opts[:preload])
    |> Repo.get_by(clauses)
  end

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
  Updates transaction status.
  """
  @spec update_status(Schema.t(), atom()) :: EctoUtils.write()
  def update_status(%Transaction{} = transaction, status) when is_atom(status),
    do: update_transaction(transaction, %{status: status})

  @doc """
  Updates a transaction.

  Only certain fields can be updated based on transaction status.
  """
  @spec update_transaction(Schema.t(), map()) :: EctoUtils.write()
  def update_transaction(%Transaction{} = transaction, attrs) do
    transaction
    |> Transaction.changeset(attrs)
    |> Repo.update()
  end

  #
  # Private functions
  #

  defp create_ledger_entry(transaction) do
    ledger_attrs = %{
      account_id: transaction.account_id,
      amount: transaction.amount,
      entry_type: infer_ledger_entry_type(transaction.transaction_type),
      transaction_id: transaction.id
    }

    Ledgers.create(ledger_attrs)
  end

  @spec infer_ledger_entry_type(atom()) :: :credit | :debit
  defp infer_ledger_entry_type(transaction_types)
       when transaction_types in [:deposit, :interest_payment],
       do: :credit

  defp infer_ledger_entry_type(_transaction_types), do: :debit

  @spec maybe_log(Ecto.UUID.t(), String.t(), tuple()) :: :ok
  defp maybe_log(transaction_id, where, error)
       when is_binary(transaction_id) and is_binary(where) and elem(error, 0) == :error do
    log_error = Tuple.delete_at(error, 0)

    Logger.warning(
      "Transaction #{transaction_id} warning thrown on #{where} with error #{inspect(log_error)}"
    )

    :ok
  end

  defp update_complete(transaction, metadata) do
    transaction
    |> Transaction.complete_changeset(metadata)
    |> Repo.update()
  end
end
