defmodule Bank.AccountsFixtures do
  @moduledoc """
  Test helpers for creating account entities via the data layer.
  """

  alias Bank.Accounts

  def account_fixture(attrs \\ %{}) do
    user = Map.get(attrs, :user) || Bank.UsersFixtures.user_fixture()

    default_attrs = %{
      account_number: "3171377546",
      account_type: :checking,
      currency: "EUR",
      name: "Test Account",
      status: :active,
      user_id: user.id
    }

    merged_attrs = Map.merge(default_attrs, Map.delete(attrs, :user))

    {:ok, account} = Accounts.create(merged_attrs)
    account
  end
end
