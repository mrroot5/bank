defmodule Bank.Transactions.TransactionMetadata do
  @moduledoc """
  Embedded schema for flexible transaction metadata.
  """
  use Bank.Ecto.Schema

  @initiated_by_types ~w(admin system user)a

  @primary_key false
  embedded_schema do
    field :completed_by, :string

    # Failure tracking
    field :failed_at, :utc_datetime
    field :failure_code, :string
    field :failure_reason, :string

    # Process tracking
    field :initiated_by_id, :binary_id

    field :initiated_by_type, Ecto.Enum,
      values: @initiated_by_types,
      default: nil

    field :processed_at, :utc_datetime

    # External origin tracking
    # e.g., PayPal, Stripe, etc.
    field :origin_external, :string
    # PayPal transaction ID, etc.
    field :origin_reference, :string
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(metadata, attrs) do
    metadata
    |> cast(attrs, [
      :completed_by,
      :failed_at,
      :failure_code,
      :failure_reason,
      :initiated_by_id,
      :initiated_by_type,
      :processed_at,
      :origin_external,
      :origin_reference
    ])
    |> validate_length(:failure_code, max: 5, allow_nil: true)
    |> validate_inclusion(:initiated_by_type, @initiated_by_types, allow_nil: true)
  end
end
