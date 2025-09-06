defmodule Bank.QueryComposer do
  @moduledoc """
  Ecto query general purpose functions.
  """

  import Ecto.Query

  alias Ecto.Query

  @list_paginated_limit 20

  @type filters_where :: [{operator :: String.t(), field_name :: atom(), field_value :: term()}]
  @type filters_others :: [{operator :: String.t(), field_value :: term()}]

  @doc """
  Filters ecto query

  ## Features

  - Filter by where: == | >= | <=.
  - Filter by limit.
  - Filter by offset.
  """
  @spec compose(Ecto.Queryable.t(), filters_where() | filters_others()) :: Query.t()
  def compose(query, nil), do: query

  def compose(query, filters) when is_list(filters),
    do: Enum.reduce(filters, query, &apply_filter/2)

  @doc """
  Filters ecto query by a range of dates

  ## Features

  - Filter by where: == | >= | <=.
  - Filter by limit.
  - Filter by offset.
  """
  @spec filter_by_date_range(Query.t(), keyword()) :: Query.t()
  def filter_by_date_range(query, opts) when is_list(opts),
    do: do_filter_by_date_range(query, opts[:from_date], opts[:to_date], opts[:date_field])

  @doc """
  Returns a paginated list of users.

  ## Options
  * :offset - offset for pagination
  * :limit - limit for pagination

  ## Examples
      iex> list_paginated(offset: 0, limit: 20)
      [%User{}, ...]

  ## Docs

  https://hexdocs.pm/phoenix_live_view/bindings.html#scroll-events-and-infinite-pagination
  """
  @spec list_paginated(Ecto.Queryable.t(), keyword()) :: Query.t()
  def list_paginated(schema, opts \\ []) do
    limit = Keyword.get(opts, :limit, @list_paginated_limit)
    after_id = Keyword.get(opts, :after_id, false)

    base_query = from(u in schema)

    if after_id do
      from u in base_query, where: u.id > ^after_id, order_by: [asc: u.id], limit: ^limit
    else
      from u in base_query, order_by: [asc: u.id], limit: ^limit
    end
  end

  @spec maybe_preload(Ecto.Queryable.t(), [atom()] | nil) :: Query.t()
  def maybe_preload(query, nil), do: query
  def maybe_preload(query, []), do: query
  def maybe_preload(query, preloads) when is_list(preloads), do: preload(query, ^preloads)

  #
  # Private function
  #

  # Compose related functions

  defp apply_filter({"eq", field_name, value}, query),
    do: where(query, [t], field(t, ^field_name) == ^value)

  defp apply_filter({"gte", field_name, value}, query),
    do: where(query, [t], field(t, ^field_name) >= ^value)

  defp apply_filter({"lte", field_name, value}, query),
    do: where(query, [t], field(t, ^field_name) <= ^value)

  defp apply_filter({"or_eq", field_name, value}, query),
    do: or_where(query, [t], field(t, ^field_name) == ^value)

  defp apply_filter({"limit", limit}, query),
    do: limit(query, ^limit)

  defp apply_filter({"offset", offset}, query),
    do: offset(query, ^offset)

  defp apply_filter(_, query), do: query

  # Date related functions

  defp date_field_default(nil), do: :inserted_at
  defp date_field_default(field) when is_atom(field), do: field

  @spec do_filter_by_date_range(Query.t(), DateTime.t() | nil, DateTime.t() | nil, atom() | nil) ::
          Query.t()
  defp do_filter_by_date_range(query, from_date, to_date, date_field)

  defp do_filter_by_date_range(query, nil, nil, _), do: query

  defp do_filter_by_date_range(query, from_date, nil, date_field) do
    date_field = date_field_default(date_field)

    where(query, [t], field(t, ^date_field) >= ^from_date)
  end

  defp do_filter_by_date_range(query, nil, to_date, date_field) do
    date_field = date_field_default(date_field)

    where(query, [t], field(t, ^date_field) <= ^to_date)
  end

  defp do_filter_by_date_range(query, from_date, to_date, date_field) do
    date_field = date_field_default(date_field)

    where(query, [t], field(t, ^date_field) >= ^from_date and field(t, ^date_field) <= ^to_date)
  end
end
