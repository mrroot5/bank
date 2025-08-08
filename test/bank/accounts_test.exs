defmodule Bank.Accounts.AccountsTest do
  use Bank.DataCase, async: true

  alias Bank.Accounts.Account

  describe "currency immutability" do
    setup do
      user = Bank.UsersFixtures.user_fixture()
      account = Bank.AccountsFixtures.account_fixture(%{user: user})
      %{account: account}
    end

    test "cannot update currency once set (application level)", %{account: account} do
      result = Bank.Accounts.update_account(account, %{currency: "USD"})
      assert {:error, changeset} = result
      assert "cannot be changed once set" in errors_on(changeset).currency
    end

    test "cannot update currency once set (database level)", %{account: account} do
      # Directly update via Repo to bypass changeset validation
      changeset = Ecto.Changeset.change(account, currency: "USD")

      assert_raise Postgrex.Error, ~r/Currency cannot be updated once set/, fn ->
        Bank.Repo.update!(changeset)
      end
    end
  end
end
