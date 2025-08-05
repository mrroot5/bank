defmodule Bank.Accounts.Account do
  @moduledoc """
  Bank account that holds balances.
  """
  use Bank.Schema

  alias Bank.Ledgers.Ledger
  alias Bank.Transactions.Transaction
  alias Bank.Users.User

  @account_types ~w(checking savings business wholesale)a
  @account_statuses ~w(active suspended closed frozen)a

  schema "accounts" do
    field :account_type, Ecto.Enum, values: @account_types, default: :checking
    # Real-time balance (updated when ledger entries are created)
    field :balance, :decimal, default: Decimal.new("0.000000")
    field :balance_updated_at, :utc_datetime
    field :currency, :string, default: "EUR"
    field :status, Ecto.Enum, values: @account_statuses, default: :active

    belongs_to :user, User
    has_many :ledgers, Ledger
    has_many :transactions, Transaction

    timestamps(type: :utc_datetime)
  end

  def balance_changeset(account, new_balance) do
    account
    |> change(balance: new_balance, balance_updated_at: DateTime.utc_now())
  end

  def changeset(account, attrs) do
    account
    |> cast(attrs, [
      :account_number,
      :account_type,
      :currency,
      :metadata,
      :name,
      :status,
      :user_id
    ])
    |> validate_required([:account_number, :account_type, :currency, :name, :user_id])
    |> validate_inclusion(:account_type, @account_types)
    |> validate_inclusion(:status, @account_statuses)
    |> validate_length(:currency, is: 3)
    |> validate_number(:balance, greater_than_or_equal_to: Decimal.new("-1000"))
    |> validate_format(:account_number, ~r/^[A-Z0-9]{10,20}$/)
    |> prevent_currency_update(account)
    |> unique_constraint(:account_number)
    |> foreign_key_constraint(:user_id)
  end

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
