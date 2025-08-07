defmodule Bank.Accounts.Account do
  @moduledoc """
  Bank account that holds balances.
  """
  use Bank.Ecto.Schema

  alias Bank.Accounts.AccountMetadata
  alias Bank.Ledgers.Ledger
  alias Bank.Transactions.Transaction
  alias Bank.Users.User
  alias Ecto.Changeset
  alias Ecto.Schema

  @account_types ~w(checking savings business wholesale)a
  @account_statuses ~w(active suspended closed)a

  schema "accounts" do
    field :account_number, :string
    field :account_type, Ecto.Enum, values: @account_types, default: :checking
    # Real-time balance (updated when ledger entries are created)
    field :balance, :decimal, default: Decimal.new("0.000000")
    field :balance_updated_at, :utc_datetime
    field :currency, :string, default: "EUR"
    field :name, :string
    field :status, Ecto.Enum, values: @account_statuses, default: :active

    embeds_one :metadata, AccountMetadata, on_replace: :update

    belongs_to :user, User
    has_many :ledgers, Ledger
    has_many :transactions, Transaction

    timestamps(type: :utc_datetime)
  end

  @spec account_number_changeset(Schema.t() | Changeset.t(), map()) :: Changeset.t()
  def account_number_changeset(data, attrs) do
    data
    |> cast(attrs, [:account_number])
    |> validate_required([:account_number])
    |> validate_format(:account_number, ~r/^[0-9]{10}$/)
    |> unique_constraint(:account_number)
  end

  @spec balance_changeset(Schema.t(), integer()) :: Changeset.t()
  def balance_changeset(account, new_balance),
    do: change(account, balance: new_balance, balance_updated_at: DateTime.utc_now())

  @spec changeset(Schema.t(), map()) :: Changeset.t()
  def changeset(account, attrs) do
    account
    |> cast(attrs, [
      :account_type,
      :currency,
      :name,
      :status,
      :user_id
    ])
    |> cast_embed(:metadata, with: &AccountMetadata.changeset/2)
    |> account_number_changeset(attrs)
    |> validate_required([:account_type, :currency, :name, :user_id])
    |> validate_inclusion(:account_type, @account_types)
    |> validate_inclusion(:status, @account_statuses)
    |> validate_length(:currency, is: 3)
    |> validate_number(:balance, greater_than_or_equal_to: Decimal.new("-1000"))
    |> prevent_currency_update(account)
    |> foreign_key_constraint(:user_id)
  end

  @spec defaults_changeset(Schema.t(), map()) :: Changeset.t()
  def defaults_changeset(account, attrs) do
    account
    |> cast(attrs, [
      :account_type,
      :currency,
      :status,
      :user_id
    ])
    |> cast_embed(:metadata, with: &AccountMetadata.changeset/2)
  end

  @spec prevent_currency_update(Changeset.t(), map()) :: Changeset.t()
  defp prevent_currency_update(changeset, %{currency: old_currency}) do
    case fetch_change(changeset, :currency) do
      {:ok, new_currency} when new_currency != old_currency ->
        add_error(changeset, :currency, "cannot be changed once set")

      _ ->
        changeset
    end
  end

  defp prevent_currency_update(changeset, _), do: changeset
end
