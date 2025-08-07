defmodule Bank.Accounts.AccountMetadata do
  @moduledoc """
  Embedded schema for flexible Account metadata.
  """
  use Bank.Ecto.Schema

  @primary_key false
  embedded_schema do
    field :iban, :string
    field :swift, :string
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(metadata, attrs) do
    metadata
    |> cast(attrs, [
      :iban,
      :swift
    ])
    |> validate_length(:iban, is: 24, allow_nil: true)
    |> validate_format(:iban, ~r/^ES\d{2}2525\d{16}$/, allow_nil: true)
    |> validate_length(:swift, is: 11, allow_nil: true)
    |> validate_format(:swift, ~r/^BANKES[A-Z0-9]{5}$/, allow_nil: true)
  end
end
