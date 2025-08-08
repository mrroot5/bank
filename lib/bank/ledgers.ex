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
  def list(opts \\ []) do
    Ledger
    |> QueryComposer.compose(opts)
    |> QueryComposer.filter_by_date_range(opts)
    |> order_by(^(opts[:order_by] || [desc: :inserted_at]))
    |> QueryComposer.maybe_preload(opts[:preload])
    |> Repo.all()
  end

  @doc """
  Gets a single ledger entry.

  Raises `Ecto.NoResultsError` if the Ledger does not exist.
  """
  def get!(id, opts \\ []) do
    Ledger
    |> QueryComposer.maybe_preload(opts[:preload])
    |> Repo.get!(id)
  end

  @doc """
  Creates a ledger entry.

  Ledger entries are immutable once created.

  ## Examples

      iex> create(%{field: value})
      {:ok, %Ledger{}}

      iex> create(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create(attrs \\ %{}) do
    %Ledger{}
    |> Ledger.changeset(attrs)
    |> Repo.insert()
  end
end
