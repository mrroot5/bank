defmodule Bank.QueryComposer do
  @moduledoc """
  Ecto query general purpose functions.
  """

  import Ecto.Query

  alias Ecto.Query

  @type filters_where :: [{operator :: String.t(), field_name :: atom(), field_value :: term()}]
  @type filters_others :: [{operator :: String.t(), field_value :: term()}]

  @doc """
  Filters ecto query

  ## Features

  - Filter by where: == | >= | <=.
  - Filter by limit.
  - Filter by offset.
  """
  @spec compose(Query.t(), filters_where() | filters_others()) :: Query.t()
  def compose(query, filters) when is_list(filters) do
    Enum.reduce(filters, query, fn
      {"eq", field_name, value}, query ->
        where(query, [t], field(t, ^field_name) == ^value)

      {"gte", field_name, value}, query ->
        where(query, [t], field(t, ^field_name) == ^value)

      {"lte", field_name, value}, query ->
        where(query, [t], field(t, ^field_name) == ^value)

      {"limit", limit}, query ->
        limit(query, ^limit)

      {"offset", offset}, query ->
        offset(query, ^offset)

      _, query ->
        query
    end)
  end

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
