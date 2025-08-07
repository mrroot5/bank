defmodule Bank.Accounts do
  @moduledoc """
  The Accounts context.

  Handles bank account operations with focus on data integrity,
  concurrent balance updates, and transaction safety.
  """

  import Ecto.Query, warn: false

  alias Bank.EctoUtils
  alias Bank.Accounts.Account
  alias Bank.Accounts.IBANGenerator
  alias Bank.Accounts.SWIFTGenerator
  alias Bank.QueryComposer
  alias Bank.Repo
  alias Ecto.Schema
  alias Ecto.UUID

  @doc """
  Returns the list of accounts.
  """
  @spec list_accounts(keyword()) :: [Schema.t()]
  def list_accounts(opts \\ []) do
    Account
    |> QueryComposer.compose(opts)
    |> QueryComposer.maybe_preload(opts[:preload])
    |> Repo.all()
  end

  @doc """
  Gets a single account.

  Raises `Ecto.NoResultsError` if the Account does not exist.
  """
  @spec get_account!(UUID.t(), keyword()) :: Schema.t()
  def get_account!(id, opts \\ []) do
    Account
    |> QueryComposer.maybe_preload(opts[:preload])
    |> Repo.get!(id)
  end

  @doc """
  Gets a single account by account number.
  """
  @spec get_account_by_number(binary(), keyword()) :: Schema.t()
  def get_account_by_number(account_number, opts \\ []) do
    Account
    |> where(account_number: ^account_number)
    |> QueryComposer.maybe_preload(opts[:preload])
    |> Repo.one()
  end

  @doc """
  Creates an account.

  ## Examples

      iex> create_account(%{field: value})
      {:ok, %Account{}}

      iex> create_account(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  @spec create_account(map()) :: EctoUtils.write()
  def create_account(attrs \\ %{}) do
    changeset = Account.changeset(%Account{}, attrs)

    if changeset.valid? do
      account_number = generate_account_number()

      new_attrs = %{
        account_number: account_number,
        iban: IBANGenerator.generate(account_number: account_number),
        swift: SWIFTGenerator.generate()
      }

      attrs = Map.merge(new_attrs, attrs)

      changeset
      |> Account.changeset(attrs)
      |> Repo.insert()
    else
      changeset
    end
  end

  @doc """
  Updates an account.

  ## Examples

      iex> update_account(account, %{field: new_value})
      {:ok, %Account{}}

      iex> update_account(account, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  @spec update_account(Schema.t(), map()) :: EctoUtils.write()
  def update_account(%Account{} = account, attrs) do
    account
    |> Account.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates account balance atomically.

  This function should be called within a transaction after creating
  ledger entries to maintain consistency.
  """
  @spec update_balance(Schema.t(), struct()) :: EctoUtils.write()
  def update_balance(%Account{} = account, new_balance) when is_struct(new_balance, Decimal) do
    account
    |> Account.balance_changeset(new_balance)
    |> Repo.update()
  end

  @doc """
  Suspends an account.
  """
  @spec suspend_account(Schema.t()) :: EctoUtils.write()
  def suspend_account(%Account{} = account), do: update_account(account, %{status: :suspended})

  @doc """
  Closes an account.

  Only accounts with zero balance can be closed.
  """
  @spec close_account(Schema.t()) :: EctoUtils.write()
  def close_account(%Account{balance: balance} = account) do
    if Decimal.eq?(balance, Decimal.new("0")) do
      update_account(account, %{status: :closed})
    else
      {:error, :non_zero_balance}
    end
  end

  @doc """
  Reactivates a suspended account.
  """
  @spec reactivate_account(Schema.t()) :: EctoUtils.write()
  def reactivate_account(%Account{status: :suspended} = account),
    do: update_account(account, %{status: :active})

  def reactivate_account(%Account{}), do: {:error, :invalid_status}

  # Private functions

  @spec generate_account_number :: String.t()
  defp generate_account_number,
    do: Enum.map_join(1..10, fn _ -> :rand.uniform(10) - 1 end)

  @spec maybe_preload(Ecto.Query.t(), []) :: Ecto.Query.t()
  defp maybe_preload(query, nil), do: query
  defp maybe_preload(query, []), do: query
  defp maybe_preload(query, preloads), do: preload(query, ^preloads)
end
