defmodule Bank.Ecto.Utils do
  @moduledoc """
  A simple module to help with Ecto.Repo specs.

  ## Type

  Currently types are Ecto.Repo outputs.

  - read: get, one.
  - write: insert, update, delete.
  """

  @type read :: Ecto.Schema.t() | term() | nil
  @type write :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
end
