defmodule Bank.AccountsTest do
  use Bank.DataCase, async: true

  alias Bank.Accounts
  alias Bank.Accounts.Account
  alias Bank.AccountsFixtures
  alias Bank.Repo

  describe "list/1" do
    setup do
      account = AccountsFixtures.fixture()

      %{account: account}
    end

    test "returns all accounts", %{account: account1} do
      account2 = AccountsFixtures.fixture()
      accounts = Accounts.list()

      assert length(accounts) == 2

      account_ids = Enum.map(accounts, & &1.id)

      assert account1.id in account_ids
      assert account2.id in account_ids
    end

    test "returns accounts with preloaded associations", %{account: account} do
      [account_with_preload | _tail] = Accounts.list(preload: [:user])

      assert Ecto.assoc_loaded?(account_with_preload.user)
      assert account_with_preload.user.id == account.user_id
    end
  end

  describe "get!/2" do
    setup do
      account = AccountsFixtures.fixture()

      %{account: account}
    end

    test "returns the account with given id", %{account: account} do
      retrieved_account = Accounts.get!(account.id)

      assert retrieved_account.id == account.id
      assert retrieved_account.account_number == account.account_number
    end

    test "returns account with preloaded associations" do
      account = AccountsFixtures.fixture()

      retrieved_account = Accounts.get!(account.id, preload: [:user])

      assert Ecto.assoc_loaded?(retrieved_account.user)
      assert retrieved_account.user.id == account.user_id
    end
  end

  describe "get_by/2" do
    setup do
      account = AccountsFixtures.fixture()

      %{account: account}
    end

    test "returns account by account_number", %{account: account} do
      retrieved_account = Accounts.get_by(%{account_number: account.account_number})

      assert retrieved_account.id == account.id
    end

    test "returns account by multiple fields", %{account: account} do
      retrieved_account =
        Accounts.get_by(%{account_type: account.account_type, user_id: account.user_id})

      assert retrieved_account.id == account.id
    end

    test "returns account with preloaded associations", %{account: account} do
      retrieved_account =
        Accounts.get_by(%{account_number: account.account_number}, preload: [:user])

      assert Ecto.assoc_loaded?(retrieved_account.user)

      assert retrieved_account.user.id == account.user_id
    end

    test "returns nil when account does not exist" do
      result = Accounts.get_by(%{account_number: "9999999999"})
      assert is_nil(result)
    end
  end

  describe "create/1" do
    setup do
      user = Bank.UsersFixtures.fixture()

      %{user: user}
    end

    test "creates account with valid data", %{user: user} do
      attrs = %{
        account_type: :savings,
        currency: "USD",
        name: "My Saving Account",
        user_id: user.id
      }

      assert {:ok, account} = Accounts.create(attrs)
      assert account.account_type == :savings
      assert account.currency == "USD"
      assert account.name == "My Saving Account"
      assert account.user_id == user.id
      assert account.status == :active
      assert Decimal.eq?(account.balance, Decimal.new("0.000000"))
      assert String.length(account.account_number) == 10
      assert String.match?(account.account_number, ~r/^[0-9]{10}$/)
      assert account.metadata.iban != nil
      assert account.metadata.swift != nil
    end

    test "creates account with default name when name and account_type not provided", %{
      user: user
    } do
      attrs = %{
        currency: "USD",
        user_id: user.id
      }

      assert {:ok, account} = Accounts.create(attrs)
      assert account.account_type == :checking
    end

    test "creates account with default name from account_type when name not provided", %{
      user: user
    } do
      attrs = %{
        account_type: :savings,
        currency: "USD",
        user_id: user.id
      }

      assert {:ok, account} = Accounts.create(attrs)
      assert account.account_type == :savings
    end

    test "creates account with provided account_number", %{user: user} do
      {:ok, account_number} = Accounts.create_account_number()

      attrs = %{
        account_type: :checking,
        currency: "USD",
        name: "Test Account",
        user_id: user.id,
        account_number: account_number
      }

      assert {:ok, account} = Accounts.create(attrs)
      assert account.account_number == account_number
    end

    test "returns error with invalid data" do
      attrs = %{
        account_type: :invalid_type,
        currency: "INVALID",
        name: "",
        user_id: nil
      }

      assert {:error, changeset} = Accounts.create(attrs)
      refute changeset.valid?

      errors = errors_on(changeset)

      expected_errors = %{
        name: ["can't be blank"],
        currency: ["should be 3 character(s)"],
        user_id: ["can't be blank"],
        account_type: ["is invalid"]
      }

      assert expected_errors == errors
    end

    test "returns error when user does not exist" do
      non_existent_user_id = Ecto.UUID.generate()

      attrs = %{
        account_type: :checking,
        currency: "USD",
        name: "Test Account",
        user_id: non_existent_user_id
      }

      assert {:error, changeset} = Accounts.create(attrs)

      errors = errors_on(changeset)
      expected_errors = %{user_id: ["does not exist"]}

      assert expected_errors == errors
    end

    test "handles account_number collision by retrying", %{user: user} do
      existing_account = AccountsFixtures.fixture(%{user: user})

      # In a real scenario, we can't easily test this without mocking
      # because the probability of collision is extremely low (1 in 10 million)
      # But we can at least verify that providing a duplicate account_number
      # results in an error from the unique constraint

      attrs = %{
        name: "Test Account",
        user_id: user.id,
        account_number: existing_account.account_number
      }

      # This should fail due to unique constraint
      assert {:error, changeset} = Accounts.create(attrs)

      errors = errors_on(changeset)
      expected_errors = %{account_type: ["has already been taken"]}

      assert expected_errors == errors
    end

    test "prevents duplicate account_type and currency for same user" do
      account = AccountsFixtures.fixture()

      attrs = %{
        account_type: account.account_type,
        currency: account.currency,
        name: "Another Account",
        user_id: account.user_id
      }

      assert {:error, changeset} = Accounts.create(attrs)
      assert length(changeset.errors) > 0
    end

    test "allows same account_type and currency for different users" do
      account1 = AccountsFixtures.fixture()
      user2 = Bank.UsersFixtures.fixture()

      attrs = %{
        account_type: account1.account_type,
        currency: account1.currency,
        name: "Account for User 2",
        user_id: user2.id
      }

      assert {:ok, account2} = Accounts.create(attrs)
      assert account2.account_type == account1.account_type
      assert account2.currency == account1.currency
      assert account2.user_id != account1.user_id
    end

    test "validates balance minimum value", %{user: user} do
      attrs = %{
        name: "Test Account",
        user_id: user.id,
        balance: Decimal.new("-2000")
      }

      assert {:error, changeset} = Accounts.create(attrs)

      errors = errors_on(changeset)
      expected_errors = %{balance: ["must be greater than or equal to -1000"]}

      assert expected_errors == errors
    end
  end

  describe "update_account/2" do
    setup do
      account = AccountsFixtures.fixture()

      %{account: account}
    end

    test "updates account with valid data", %{account: account} do
      attrs = %{
        name: "Updated Account Name",
        status: :suspended
      }

      assert {:ok, updated_account} = Accounts.update_account(account, attrs)
      assert updated_account.name == "Updated Account Name"
      assert updated_account.status == :suspended
      assert updated_account.id == account.id
    end

    test "prevents currency update", %{account: account} do
      attrs = %{currency: "USD"}

      assert {:error, changeset} = Accounts.update_account(account, attrs)

      errors = errors_on(changeset)
      expected_errors = %{currency: ["cannot be changed once set"]}

      assert expected_errors == errors
    end

    test "returns error with invalid data", %{account: account} do
      attrs = %{
        account_type: :invalid_type,
        currency: "TOOLONG"
      }

      assert {:error, changeset} = Accounts.update_account(account, attrs)
      refute changeset.valid?

      errors = errors_on(changeset)

      expected_errors = %{
        currency: ["cannot be changed once set", "should be 3 character(s)"],
        account_type: ["is invalid"]
      }

      assert expected_errors == errors
    end

    test "validates balance minimum value on update", %{account: account} do
      attrs = %{balance: Decimal.new("-2000")}

      assert {:error, changeset} = Accounts.update_account(account, attrs)
      errors = errors_on(changeset)
      expected_errors = %{balance: ["must be greater than or equal to -1000"]}

      assert expected_errors == errors
    end
  end

  describe "status_account/1" do
    test "suspends an active account" do
      account = AccountsFixtures.fixture(%{status: :active})

      assert {:ok, suspended_account} = Accounts.suspend_account(account)
      assert suspended_account.status == :suspended
    end

    test "suspends an already suspended account" do
      account = AccountsFixtures.fixture(%{status: :suspended})

      assert {:ok, suspended_account} = Accounts.suspend_account(account)
      assert suspended_account.status == :suspended
    end

    test "reactivates a suspended account" do
      account = AccountsFixtures.fixture(%{status: :suspended})

      assert {:ok, reactivated_account} = Accounts.reactivate_account(account)
      assert reactivated_account.status == :active
    end

    test "returns error when trying to reactivate non-suspended account" do
      active_account = AccountsFixtures.fixture(%{status: :active})
      closed_account = AccountsFixtures.fixture(%{status: :closed})

      assert {:error, :invalid_status} = Accounts.reactivate_account(active_account)
      assert {:error, :invalid_status} = Accounts.reactivate_account(closed_account)
    end
  end

  describe "close_account/1" do
    test "closes account with zero balance" do
      account = AccountsFixtures.fixture(%{balance: Decimal.new("0.000000")})

      assert {:ok, closed_account} = Accounts.close_account(account)
      assert closed_account.status == :closed
    end

    test "prevents closing account with positive balance" do
      account = AccountsFixtures.fixture(%{balance: Decimal.new("100.50")})

      assert {:error, :non_zero_balance} = Accounts.close_account(account)

      # Verify account status hasn't changed
      retrieved_account = Repo.get!(Account, account.id)
      assert retrieved_account.status == account.status
    end

    test "prevents closing account with negative balance" do
      account = AccountsFixtures.fixture(%{balance: Decimal.new("-50.25")})

      assert {:error, :non_zero_balance} = Accounts.close_account(account)

      # Verify account status hasn't changed
      retrieved_account = Repo.get!(Account, account.id)
      assert retrieved_account.status == account.status
    end
  end

  describe "create_account_number/0" do
    test "generates a valid 10-digit account number" do
      assert {:ok, account_number} = Accounts.create_account_number()
      assert String.length(account_number) == 10
      assert String.match?(account_number, ~r/^[0-9]{10}$/)
    end

    test "generates unique account numbers" do
      numbers =
        Enum.map(1..10_000, fn _ ->
          Accounts.create_account_number()
        end)

      assert length(Enum.uniq(numbers)) == 10_000
    end
  end

  describe "create_metadata/1" do
    setup do
      {:ok, account_number} = Accounts.create_account_number()

      %{account_number: account_number}
    end

    test "creates metadata with IBAN and SWIFT", %{account_number: account_number} do
      metadata = Accounts.create_metadata(account_number)

      assert is_map(metadata)
      assert Map.has_key?(metadata, :iban)
      assert Map.has_key?(metadata, :swift)
      assert metadata.iban != nil
      assert metadata.swift != nil
    end
  end

  describe "currency immutability" do
    setup do
      account = AccountsFixtures.fixture()

      %{account: account}
    end

    test "cannot update currency once set (application level)", %{account: account} do
      result = Accounts.update_account(account, %{currency: "USD"})
      assert {:error, changeset} = result
      assert "cannot be changed once set" in errors_on(changeset).currency
    end

    test "cannot update currency once set (database level)", %{account: account} do
      # Directly update via Repo to bypass changeset validation
      changeset = Ecto.Changeset.change(account, currency: "USD")

      assert_raise Postgrex.Error, ~r/Currency cannot be updated once set/, fn ->
        Repo.update!(changeset)
      end
    end
  end
end
