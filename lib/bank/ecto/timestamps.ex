defmodule Bank.Ecto.Timestamps do
  @moduledoc """
  Ecto timestamps utils
  """

  @doc """
  Return DateTime utc but in seconds avoiding ecto dates error:
  ":utc_datetime expects microseconds to be empty"
  """
  @spec utc_now_seconds :: DateTime.t()
  def utc_now_seconds, do: DateTime.utc_now(:second)
end
