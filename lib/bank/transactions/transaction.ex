defmodule Bank.Transactions.Transaction do
  @moduledoc """
  Transactions tracking.

  This table contains transaction which requires an extra step to be completed.

  ## Examples

  - Periodic transaction.
  - International transactions.
  - External transactions services (PayPal, etc.).
  """
  use Bank.Ecto.Schema
  alias Bank.Accounts.Account
  alias Bank.Ledgers.Ledger
  alias Bank.Transactions.TransactionMetadata
  alias Ecto.Changeset
  alias Ecto.Schema

  @transaction_types ~w(deposit withdrawal transfer fee_charge interest_payment)a
  @transaction_statuses ~w(pending processing completed failed cancelled)a

  schema "transactions" do
    field :amount, :decimal
    field :currency, :string
    field :description, :string
    field :idempotency_key, :string
    field :status, Ecto.Enum, values: @transaction_statuses, default: :pending
    field :transaction_type, Ecto.Enum, values: @transaction_types

    embeds_one :metadata, TransactionMetadata, on_replace: :update

    belongs_to :account, Account, foreign_key: :account_id
    has_many :ledgers, Ledger, foreign_key: :transaction_id

    timestamps()
  end

  @spec changeset(Schema.t(), map()) :: Changeset.t()
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :amount,
      :currency,
      :description,
      :idempotency_key,
      :status,
      :transaction_type,
      :account_id
    ])
    |> cast_embed(:metadata, with: &TransactionMetadata.changeset/2)
    |> validate_required([:amount, :currency, :description, :idempotency_key, :transaction_type])
    |> validate_inclusion(:transaction_type, @transaction_types)
    |> validate_inclusion(:status, @transaction_statuses)
    |> validate_length(:currency, is: 3)
    |> unique_constraint(:idempotency_key)
    |> foreign_key_constraint(:account_id)
  end

  @spec complete_changeset(Schema.t(), binary(), map()) :: Changeset.t()
  def complete_changeset(transaction, completed_by \\ "system", metadata_override \\ %{}) do
    metadata =
      %TransactionMetadata{
        completed_by: completed_by,
        processed_at: DateTime.utc_now()
      }

    transaction
    |> change(status: :completed)
    |> put_embed(:metadata, Map.merge(metadata, metadata_override))
  end

  @spec fail_changeset(Schema.t(), binary(), binary() | nil, map()) :: Changeset.t()
  def fail_changeset(transaction, reason, error_code \\ nil, metadata_override \\ %{}) do
    metadata = %TransactionMetadata{
      failed_at: DateTime.utc_now(),
      failure_code: error_code,
      failure_reason: reason
    }

    transaction
    |> change(status: :failed)
    |> put_embed(:metadata, Map.merge(metadata, metadata_override))
  end
end
