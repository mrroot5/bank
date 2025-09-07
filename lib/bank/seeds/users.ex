defmodule Bank.Seeds.Users do
  @moduledoc """
  Seed helpers for the Bank app.
  """

  require Logger

  import Ecto.Query, only: [from: 2]

  alias Bank.Repo
  alias Bank.Users
  alias Bank.Users.User

  @doc """
  Seeds users unless the users table is already populated.
  Pass force: true to always seed, even if users exist.
  """
  def seed(count, opts \\ []) do
    force = Keyword.get(opts, :force, false)

    if !force and users_exist?() do
      IO.puts("Users table already populated. Skipping user seeding.")
      :ok
    else
      IO.puts("Seeding \\#{count} users...")
      users = Enum.map(1..count, &user_attrs/1)

      create_admin()

      users
      |> Enum.chunk_every(500)
      |> Enum.each(fn chunk ->
        chunk
        |> Enum.map(&Users.register_user/1)
        |> Enum.each(fn
          {:ok, _user} ->
            :ok

          {:error, changeset} ->
            Logger.warning("Failed user with error: #{inspect(changeset.errors)}")
        end)
      end)

      IO.puts("Done seeding users.")

      :ok
    end
  end

  #
  # Private functions
  #

  defp create_admin do
    attrs = %{
      email: "admin@admin.com",
      password: "Password123!-admin",
      roles: [:superuser, :user],
      confirmed_at: DateTime.utc_now()
    }

    Users.register_user(attrs)
  end

  # defp create_user(attrs), do: Users.register_user(attrs)

  defp user_attrs(n) do
    %{
      email: "user_#{n}@example.com",
      password: "Password123!-#{n}",
      roles: [:user],
      confirmed_at: DateTime.utc_now()
    }
  end

  defp users_exist?, do: Repo.exists?(from u in User, select: 1)
end
