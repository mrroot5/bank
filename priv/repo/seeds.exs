# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Bank.Repo.insert!(%Bank.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Seeding
# To force seeding even if data exist, pass force: true

default_count = "COUNT_SEED" |> System.get_env("10") |> String.to_integer()

force? = "FORCE_SEED" |> System.get_env("true") |> String.to_atom()

Bank.Seeds.Users.seed(default_count, force: force?)
Bank.Seeds.Accounts.seed(default_count, force: force?)
Bank.Seeds.Transactions.seed(default_count, force: force?)
Bank.Seeds.Ledgers.seed(force: force?)
