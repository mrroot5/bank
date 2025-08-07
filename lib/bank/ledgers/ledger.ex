defmodule Bank.Ledgers.Ledger do
  @moduledoc """
  IMMUTABLE financial ledger entries. These represent actual money movements.

  This table contains immediate transactions, like ATM or other completed transactions.
  """
  use Bank.Ecto.Schema
  alias Bank.Accounts.Account
  alias Bank.Transactions.Transaction

  @entry_types ~w(debit credit)a

  schema "ledgers" do
    field :amount, :decimal
    field :entry_type, Ecto.Enum, values: @entry_types

    belongs_to :account, Account
    belongs_to :transaction, Transaction

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(ledger, attrs) do
    ledger
    |> cast(attrs, [:amount, :currency, :entry_type, :origin, :account_id, :transaction_id])
    |> validate_required([:account_id, :amount, :currency, :entry_type])
    |> validate_inclusion(:entry_type, @entry_types)
    |> validate_length(:currency, is: 3)
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:transaction_id)
  end
end
