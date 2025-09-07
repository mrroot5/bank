defmodule Bank.Seeds.Accounts do
  @moduledoc """
  Seed helpers for bank accounts.
  """

  require Logger

  import Ecto.Query, only: [from: 2]

  alias Bank.Accounts
  alias Bank.Accounts.Account
  alias Bank.Repo
  alias Bank.Users
  alias Bank.Users.User

  @doc """
  Seeds accounts unless the accounts table is already populated.
  Pass force: true to always seed, even if accounts exist.
  """
  def seed(count, opts \\ []) do
    force = Keyword.get(opts, :force, false)

    if !force and accounts_exist?() do
      IO.puts("Accounts table already populated. Skipping account seeding.")
      :ok
    else
      IO.puts("Seeding \\#{count} accounts...")
      users = Repo.all(User)

      if users == [] do
        IO.puts("No users found. Please seed users first.")
        :error
      else
        accounts_attrs = Enum.map(1..count, &account_attrs(&1, users))

        accounts_attrs
        |> Enum.chunk_every(500)
        |> Enum.each(fn chunk ->
          chunk
          |> Enum.reject(fn attrs -> attrs == nil end)
          |> Enum.map(&Accounts.create/1)
          |> Enum.each(fn
            {:ok, _account} ->
              :ok

            {:error, changeset} ->
              Logger.warning("Failed account with error: #{inspect(changeset.errors)}")
          end)
        end)

        create_admin_all_type_accounts()

        IO.puts("Done seeding accounts.")
        :ok
      end
    end
  end

  # Private functions

  defp account_attrs(n, users) do
    user = Enum.at(users, rem(n - 1, length(users)))
    currency = Enum.random(["EUR", "USD", "GBP", "JPY"])

    type =
      if user.email == "admin@admin.com" do
        :checking
      else
        Enum.random([:checking, :savings, :business, :wholesale])
      end

    %{
      account_type: type,
      balance: Decimal.new(Enum.random(0..10000)),
      currency: currency,
      name: "#{Atom.to_string(type)}-#{n}",
      user_id: user.id
    }
  end

  defp accounts_exist?, do: Repo.exists?(from a in Account, select: 1)

  defp create_admin_account(account_type, admin) do
    1
    |> account_attrs([admin])
    |> Map.merge(%{account_type: account_type, currency: "EUR"})
    |> Accounts.create()
  end

  defp create_admin_all_type_accounts do
    admin = Users.get_user_by_email("admin@admin.com")

    Enum.each([:checking, :savings, :business, :wholesale], &create_admin_account(&1, admin))
  end
end
