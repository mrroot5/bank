defmodule Bank.Accounts.LedgersTest do
  use Bank.DataCase, async: true

  alias Bank.Accounts.Account

  describe "updates" do
    setup do
      # Create a user for testing
      user = insert(:user)

      account =
        Bank.AccountsFixtures.account_fixture(%{
          user: user,
          name: "Ledgers account"
        })

      {:ok, user: user, account: account}
    end

    test "ledgers cannot be updated (trigger enforced)" do
      ledger = insert!(:ledger, amount: Decimal.new("10.00"))

      assert_raise Postgrex.Error, ~r/Ledger entries are immutable/, fn ->
        ledger
        |> Ecto.Changeset.change(amount: Decimal.new("20.00"))
        |> Repo.update()
      end
    end
  end
end
