defmodule Bank.Ledgers do
  @moduledoc """
  The Ledgers context.

  Handles immutable ledger entries for maintaining an audit trail
  of all financial movements. Ledger entries cannot be updated or
  deleted once created.
  """

  import Ecto.Query, warn: false

  alias Bank.Accounts
  alias Bank.Ledgers.Ledger
  alias Bank.QueryComposer
  alias Bank.Repo
  alias Ecto.Schema

  @doc """
  Creates a ledger entry.

  Ledger entries are immutable once created.

  ## Examples

      iex> create(%{field: value})
      {:ok, %Ledger{}}

      iex> create(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  @spec create(map()) :: {:ok, {Schema.t(), Schema.t()}} | {:error, Ecto.Changeset.t()}
  def create(attrs \\ %{}) do
    Repo.transact(fn ->
      ledger_result =
        %Ledger{}
        |> Ledger.changeset(attrs)
        |> Repo.insert()

      with {:ok, ledger} <- ledger_result,
           account <- Accounts.get!(ledger.account_id),
           new_balance <- calculate_new_balance(ledger, account.balance),
           {:ok, updated_account} <-
             Accounts.update_account(account, %{balance: new_balance}) do
        {:ok, {ledger, updated_account}}
      end
    end)
  end

  @doc """
  Gets a single ledger entry.

  Raises `Ecto.NoResultsError` if the Ledger does not exist.
  """
  @spec get!(String.t(), keyword()) :: Schema.t()
  def get!(id, opts \\ []) do
    Ledger
    |> QueryComposer.maybe_preload(opts[:preload])
    |> Repo.get!(id)
  end

  @doc """
  Get by whatever field you want
  """
  @spec get_by(map() | keyword(), keyword()) :: Schema.t()
  def get_by(clauses, opts \\ []) do
    Ledger
    |> QueryComposer.maybe_preload(opts[:preload])
    |> Repo.get_by(clauses)
  end

  @doc """
  Returns the list of ledger entries.
  """
  @spec list(keyword()) :: [Schema.t()]
  def list(opts \\ []) do
    Ledger
    |> QueryComposer.compose(opts[:filters])
    |> QueryComposer.filter_by_date_range(opts)
    |> order_by(^(opts[:order_by] || [desc: :inserted_at]))
    |> QueryComposer.maybe_preload(opts[:preload])
    |> Repo.all()
  end

  #
  # Private functions
  #

  @spec calculate_new_balance(Schema.t(), Decimal.t()) :: Decimal.t()
  defp calculate_new_balance(%{amount: amount, entry_type: :credit}, balance),
    do: Decimal.add(balance, amount)

  defp calculate_new_balance(%{amount: amount, entry_type: :debit}, balance) do
    amount
    |> Decimal.negate()
    |> Decimal.add(balance)
  end
end
