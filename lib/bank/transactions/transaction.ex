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

  import Ecto.Query

  alias Bank.Accounts.Account
  alias Bank.Ledgers.Ledger
  alias Bank.QueryComposer
  alias Bank.Repo
  alias Bank.Transactions.TransactionMetadata
  alias Ecto.Changeset
  alias Ecto.Schema

  @transaction_types ~w(deposit withdrawal transfer fee_charge interest_payment)a
  @transaction_statuses ~w(pending processing completed failed cancelled)a

  schema "transactions" do
    field :amount, :decimal
    field :currency, :string
    field :description, :string
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
      :status,
      :transaction_type,
      :account_id
    ])
    |> cast_embed(:metadata, with: &TransactionMetadata.changeset/2)
    |> validate_required([:amount, :currency, :description, :transaction_type, :account_id])
    |> validate_inclusion(:transaction_type, @transaction_types)
    |> validate_inclusion(:status, @transaction_statuses)
    |> validate_length(:currency, is: 3)
    |> validate_number(:amount, greater_than: Decimal.new("0.0"))
    |> validate_duplicates()
    |> foreign_key_constraint(:account_id)
  end

  @spec complete_changeset(Schema.t(), map()) :: Changeset.t()
  @spec complete_changeset(%{
          :__struct__ => atom() | %{:__changeset__ => any(), optional(any()) => any()},
          optional(atom()) => any()
        }) :: Ecto.Changeset.t()
  def complete_changeset(transaction, metadata_override \\ %{}) do
    metadata =
      %{
        completed_by: metadata_override[:completed_by] || "system",
        completed_at: DateTime.utc_now()
      }

    transaction
    |> change(status: :completed)
    |> put_embed(:metadata, Map.merge(metadata, metadata_override))
  end

  @spec fail_changeset(Schema.t(), binary(), binary() | nil, map()) :: Changeset.t()
  def fail_changeset(transaction, reason, error_code \\ nil, metadata_override \\ %{}) do
    metadata = %{
      failed_at: DateTime.utc_now(),
      failure_code: error_code,
      failure_reason: reason
    }

    transaction
    |> change(status: :failed)
    |> put_embed(:metadata, Map.merge(metadata, metadata_override))
  end

  @spec do_duplicate_transaction?(map()) :: boolean()
  defp do_duplicate_transaction?(changes) do
    filters = [
      {"eq", :amount, changes.amount},
      {"eq", :currency, changes.currency},
      {"eq", :transaction_type, changes.transaction_type},
      {"eq", :account_id, changes.account_id},
      {"eq", :status, :pending},
      {"or_eq", :status, :processing}
    ]

    result =
      __MODULE__
      |> select([:amount, :currency, :transaction_type, :account_id])
      |> QueryComposer.compose(filters)
      |> Repo.all()

    case result do
      [] -> false
      _ -> true
    end
  end

  @spec duplicate_transaction?(Changeset.t()) :: boolean()
  defp duplicate_transaction?(%{changes: changes}) do
    required_keys = [:amount, :transaction_type, :currency, :account_id]

    if Enum.all?(required_keys, &Map.has_key?(changes, &1)) do
      do_duplicate_transaction?(changes)
    else
      false
    end
  end

  @spec validate_duplicates(Changeset.t()) :: Changeset.t()
  defp validate_duplicates(changeset) do
    if duplicate_transaction?(changeset) do
      Ecto.Changeset.add_error(changeset, :id, "duplicated transaction")
    else
      changeset
    end
  end
end
