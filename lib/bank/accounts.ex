defmodule Bank.Accounts do
  @moduledoc """
  The Accounts context.

  Handles bank account operations with focus on data integrity,
  concurrent balance updates, and transaction safety.
  """

  import Ecto.Query, warn: false

  alias Bank.Ecto.Utils, as: EctoUtils
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
  @spec list(keyword()) :: [Schema.t()]
  def list(opts \\ []) do
    Account
    |> QueryComposer.compose(opts)
    |> QueryComposer.maybe_preload(opts[:preload])
    |> Repo.all()
  end

  @doc """
  Gets a single account.

  Raises `Ecto.NoResultsError` if the Account does not exist.
  """
  @spec get!(UUID.t(), keyword()) :: Schema.t()
  def get!(id, opts \\ []) do
    Account
    |> QueryComposer.maybe_preload(opts[:preload])
    |> Repo.get!(id)
  end

  @doc """
  Get by whatever field you want
  """
  @spec get_by(map() | keyword(), keyword()) :: Schema.t() | nil
  def get_by(clauses, opts \\ []) do
    Account
    |> QueryComposer.maybe_preload(opts[:preload])
    |> Repo.get_by(clauses)
  end

  @doc """
  Creates an account.

  ## Examples

      iex> create(%{field: value})
      {:ok, %Account{}}

      iex> create(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  @spec create(map(), non_neg_integer()) :: EctoUtils.write()
  def create(attrs \\ %{}, attempts \\ 3) do
    {:ok, account_number} = create_account_number(attrs)
    defaults_changeset = Account.defaults_changeset(%Account{}, attrs)
    metadata = create_metadata(account_number)

    attrs =
      attrs
      |> Map.put_new(:account_number, account_number)
      |> maybe_set_name(defaults_changeset.data)

    result =
      %Account{}
      |> Account.changeset(attrs)
      |> Account.metadata_changeset(metadata)
      |> Repo.insert()

    case result do
      {:ok, account} ->
        {:ok, account}

      {:error, changeset} when attempts <= 0 ->
        {:error, changeset}

      {:error, %Ecto.Changeset{} = changeset} ->
        if has_account_number_uniqueness_error?(changeset) do
          # Edge case where account_number was taken between generation and insertion
          attrs_without_account_number = Map.delete(attrs, :account_number)
          create(attrs_without_account_number, attempts - 1)
        else
          {:error, changeset}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @spec create_metadata(String.t()) :: map()
  def create_metadata(account_number) do
    %{
      iban: IBANGenerator.generate(account_number: account_number),
      swift: SWIFTGenerator.generate()
    }
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

  @doc """
  Creates a unique account number.

  Retries up to the specified number of attempts if duplicates are found.
  """
  @spec create_account_number(map(), non_neg_integer()) :: {:ok | :error, String.t()}
  def create_account_number(attrs \\ %{}, attempts \\ 10) do
    account_number = do_create_account_number(attrs[:account_number])
    changeset = Account.account_number_changeset(%Account{}, %{account_number: account_number})

    cond do
      changeset.valid? -> {:ok, account_number}
      attempts <= 0 -> {:error, "Max attempts"}
      true -> create_account_number(attrs, attempts - 1)
    end
  end

  @spec do_create_account_number(String.t() | nil) :: String.t()
  defp do_create_account_number(nil) do
    :crypto.strong_rand_bytes(5)
    |> :binary.decode_unsigned()
    |> rem(10_000_000_000)
    |> Integer.to_string()
    |> String.pad_leading(10, "0")
  end

  defp do_create_account_number(account_number) when is_binary(account_number), do: account_number

  @spec has_account_number_uniqueness_error?(Ecto.Changeset.t()) :: boolean()
  defp has_account_number_uniqueness_error?(changeset) do
    errors = Bank.DataCase.errors_on(changeset)

    Map.get(errors, :account_number) == ["has already been taken"]
  end

  @spec maybe_set_name(map(), %Account{}) :: map()
  defp maybe_set_name(%{name: name} = attrs, _account) when is_binary(name), do: attrs

  defp maybe_set_name(attrs, %Account{account_type: account_type})
       when is_atom(account_type) do
    name = Atom.to_string(account_type)
    Map.put_new(attrs, :name, name)
  end
end
