defmodule Bank.Schema do
  @moduledoc """
  Default schema for schemas with binary_id and foreign keys also as binary_id
  """
  defmacro __using__(_) do
    quote do
      use Ecto.Schema

      import Ecto.Changeset

      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
    end
  end
end
