defmodule Bank.Ecto.Utils do
  @moduledoc """
  A simple module to help with ecto repetitive tasks or common code across all the project.
  """

  @type get :: Ecto.Schema.t() | term() | nil
  @type write :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
end
