defmodule Bank.Ledgers do
  @moduledoc """
  The Ledgers context.

  Handles immutable ledger entries for maintaining an audit trail
  of all financial movements. Ledger entries cannot be updated or
  deleted once created.
  """

  import Ecto.Query, warn: false
  alias Bank.Repo
  alias Bank.Ledgers.Ledger
  alias Bank.QueryComposer

  @doc """
  Returns the list of ledger entries.

  ## Options

    * `:account_id` - Filter by account ID
    * `:transaction_id` - Filter by transaction ID
    * `:entry_type` - Filter by entry type (debit/credit)
    * `:origin` - Filter by origin
    * `:from_date` - Filter entries after this date
    * `:to_date` - Filter entries before this date
    * `:preload` - List of associations to preload
    * `:order_by` - Order results (default: inserted_at desc)
    * `:limit` - Maximum number of results
    * `:offset` - Number of results to skip
  """
  def list_ledgers(opts \\ %{}) do
    Ledger
    |> QueryComposer.compose(opts)
    |> QueryComposer.filter_by_date_range(opts)
    |> order_by(^(opts[:order_by] || [desc: :inserted_at]))
    |> maybe_preload(opts[:preload])
    |> Repo.all()
  end

  @doc """
  Gets a single ledger entry.

  Raises `Ecto.NoResultsError` if the Ledger does not exist.
  """
  def get_ledger!(id, opts \\ []) do
    Ledger
    |> maybe_preload(opts[:preload])
    |> Repo.get!(id)
  end

  @doc """
  Creates a ledger entry.

  Ledger entries are immutable once created.

  ## Examples

      iex> create_ledger(%{field: value})
      {:ok, %Ledger{}}

      iex> create_ledger(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_ledger(attrs \\ %{}) do
    %Ledger{}
    |> Ledger.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns daily balance summary for an account.
  """
  def daily_balance_summary(account_id, from_date, to_date) do
    from(l in Ledger,
      where: l.account_id == ^account_id,
      where: fragment("DATE(?)", l.inserted_at) >= ^from_date,
      where: fragment("DATE(?)", l.inserted_at) <= ^to_date,
      group_by: fragment("DATE(?)", l.inserted_at),
      select: %{
        date: fragment("DATE(?)", l.inserted_at),
        credits: filter(sum(l.amount), l.entry_type == :credit),
        debits: filter(sum(l.amount), l.entry_type == :debit),
        net:
          sum(
            fragment(
              "CASE WHEN ? = 'credit' THEN ? ELSE -? END",
              l.entry_type,
              l.amount,
              l.amount
            )
          )
      },
      order_by: [asc: fragment("DATE(?)", l.inserted_at)]
    )
    |> Repo.all()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking ledger changes.

  Note: Ledger entries should never be updated after creation.
  """
  def change_ledger(%Ledger{} = ledger, attrs \\ %{}), do: Ledger.changeset(ledger, attrs)

  @spec infer_entry_type(Decimal.t()) :: :credit | :debit
  def infer_entry_type(amount) do
    if Decimal.negative?(%Decimal{} = amount) do
      :debit
    else
      :credit
    end
  end

  # Private functions
  defp maybe_preload(query, nil), do: query
  defp maybe_preload(query, []), do: query
  defp maybe_preload(query, preloads), do: preload(query, ^preloads)
end
