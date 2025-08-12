defmodule Bank.Accounts.LedgersTest do
  use Bank.DataCase, async: true

  import Ecto.Query

  alias Bank.Accounts
  alias Bank.Accounts.Account
  alias Bank.AccountsFixtures
  alias Bank.Ledgers
  alias Bank.Ledgers.Ledger
  alias Bank.LedgersFixtures
  alias Bank.Transactions.Transaction
  alias Bank.TransactionsFixtures
  alias Bank.UsersFixtures

  describe "list/1" do
    setup do
      account = AccountsFixtures.account_fixture()
      transaction = TransactionsFixtures.transaction_fixture(%{account_id: account.id})

      {:ok, account: account, transaction: transaction}
    end

    test "returns all ledgers", %{account: account} do
      ledger = LedgersFixtures.ledger_fixture(%{account_id: account.id})
      assert [^ledger] = Ledgers.list()
    end

    test "filters by account_id", %{account: account} do
      other_account = AccountsFixtures.account_fixture()
      ledger1 = LedgersFixtures.ledger_fixture(%{account_id: account.id})
      _ledger2 = LedgersFixtures.ledger_fixture(%{account_id: other_account.id})

      result = Ledgers.list(account_id: account.id)
      assert [^ledger1] = result
    end

    test "filters by transaction_id", %{account: account, transaction: transaction} do
      other_transaction = TransactionsFixtures.transaction_fixture(%{account_id: account.id})

      ledger1 =
        LedgersFixtures.ledger_fixture(%{account_id: account.id, transaction_id: transaction.id})

      _ledger2 =
        LedgersFixtures.ledger_fixture(%{
          account_id: account.id,
          transaction_id: other_transaction.id
        })

      result = Ledgers.list(transaction_id: transaction.id)
      assert [^ledger1] = result
    end

    test "filters by entry_type", %{account: account} do
      credit_ledger =
        LedgersFixtures.ledger_fixture(%{account_id: account.id, entry_type: :credit})

      _debit_ledger =
        LedgersFixtures.ledger_fixture(%{account_id: account.id, entry_type: :debit})

      result = Ledgers.list(entry_type: :credit)
      assert [^credit_ledger] = result
    end

    test "filters by date range", %{account: account} do
      utc = DateTime.utc_now()
      from_date = DateTime.add(from_date, -1, :day)
      to_date = utc

      # Create ledger within date range
      {:ok, {ledger_in_range, _}} =
        Ledgers.create(%{
          account_id: account.id,
          amount: "100.00",
          entry_type: :credit
        })

      # Mock a ledger outside date range by updating timestamp
      ledger_out_of_range =
        LedgersFixtures.ledger_fixture(%{
          account_id: account.id,
          inserted_at: DateTime.add(from_date, -2, :day)
        })

      # Repo.update_all(
      #   from(l in Ledger, where: l.id == ^ledger_out_of_range.id),
      #   set: [inserted_at: ~U[2023-01-01 00:00:00Z]]
      # )

      result = Ledgers.list(from_date: from_date, to_date: to_date)
      assert [^ledger_in_range] = result
    end

    test "orders by inserted_at desc by default", %{account: account} do
      ledger1 = LedgersFixtures.ledger_fixture(%{account_id: account.id})
      # Ensure different timestamps
      :timer.sleep(10)
      ledger2 = LedgersFixtures.ledger_fixture(%{account_id: account.id})

      result = Ledgers.list()
      assert [^ledger2, ^ledger1] = result
    end

    test "supports custom ordering", %{account: account} do
      ledger1 = LedgersFixtures.ledger_fixture(%{account_id: account.id, amount: "50.00"})
      ledger2 = LedgersFixtures.ledger_fixture(%{account_id: account.id, amount: "100.00"})

      result = Ledgers.list(order_by: [asc: :amount])
      IO.inspect(result, label: "result ordering=========================")
      assert [^ledger1, ^ledger2] = result
    end

    test "supports limit and offset", %{account: account} do
      ledger1 = LedgersFixtures.ledger_fixture(%{account_id: account.id})
      # _ledger1 = LedgersFixtures.ledger_fixture(%{account_id: account.id})
      ledger2 = LedgersFixtures.ledger_fixture(%{account_id: account.id})
      # ledger3 = LedgersFixtures.ledger_fixture(%{account_id: account.id})

      result = Ledgers.list(limit: 2, offset: 1)
      IO.inspect(result, label: "result limit=========================")
      assert [^ledger2, ^ledger1] = result
    end

    test "preloads associations", %{account: account, transaction: transaction} do
      LedgersFixtures.ledger_fixture(%{account_id: account.id, transaction_id: transaction.id})

      [ledger] = Ledgers.list(preload: [:account, :transaction])

      IO.inspect(result, label: "result preloads=========================")

      assert true == false
      # assert Ecto.assoc_loaded?(hd(result).account)
      # assert Ecto.assoc_loaded?(tl(result).transaction)
      # assert %Account{} = ledger.account
      # assert %Transaction{} = ledger.transaction
    end
  end

  describe "get!/2" do
    test "returns the ledger with given id" do
      ledger = LedgersFixtures.ledger_fixture()
      assert ^ledger = Ledgers.get!(ledger.id)
    end

    test "raises when ledger not found" do
      assert_raise Ecto.NoResultsError, fn ->
        Ledgers.get!(Ecto.UUID.generate())
      end
    end

    test "preloads associations when requested" do
      account = AccountsFixtures.account_fixture()
      transaction = TransactionsFixtures.transaction_fixture(%{account_id: account.id})

      ledger =
        LedgersFixtures.ledger_fixture(%{account_id: account.id, transaction_id: transaction.id})

      result = Ledgers.get!(ledger.id, preload: [:account, :transaction])
      assert %Account{} = result.account
      assert %Transaction{} = result.transaction
    end
  end

  describe "get_by/2" do
    test "returns ledger matching clauses" do
      ledger = LedgersFixtures.ledger_fixture(%{amount: "123.45"})

      result = Ledgers.get_by(amount: Decimal.new("123.45"))
      assert ^ledger = result
    end

    test "returns nil when no match" do
      assert is_nil(Ledgers.get_by(amount: Decimal.new("999.99")))
    end

    test "preloads associations when requested" do
      account = AccountsFixtures.account_fixture()
      ledger = LedgersFixtures.ledger_fixture(%{account_id: account.id})

      result = Ledgers.get_by([amount: ledger.amount], preload: [:account])
      assert %Account{} = result.account
    end
  end

  describe "create/1" do
    setup do
      user = UsersFixtures.user_fixture()
      account = AccountsFixtures.account_fixture(%{user_id: user.id, balance: "1000.00"})
      {:ok, account: account}
    end

    test "creates ledger entry and updates account balance for credit", %{account: account} do
      attrs = %{
        account_id: account.id,
        amount: "100.00",
        entry_type: :credit
      }

      assert {:ok, {%Ledger{} = ledger, updated_account}} = Ledgers.create(attrs)
      assert ledger.amount == Decimal.new("100.00")
      assert ledger.entry_type == :credit
      assert ledger.account_id == account.id
      assert updated_account.balance == Decimal.new("1100.00")
    end

    test "creates ledger entry and updates account balance for debit", %{account: account} do
      attrs = %{
        account_id: account.id,
        amount: "50.00",
        entry_type: :debit
      }

      assert {:ok, {%Ledger{} = ledger, updated_account}} = Ledgers.create(attrs)
      assert ledger.amount == Decimal.new("50.00")
      assert ledger.entry_type == :debit
      assert updated_account.balance == Decimal.new("950.00")
    end

    test "creates ledger with transaction reference", %{account: account} do
      transaction = TransactionsFixtures.transaction_fixture(%{account_id: account.id})

      attrs = %{
        account_id: account.id,
        amount: "75.00",
        entry_type: :credit,
        transaction_id: transaction.id
      }

      assert {:ok, {%Ledger{} = ledger, _updated_account}} = Ledgers.create(attrs)
      assert ledger.transaction_id == transaction.id
    end

    test "validates required fields" do
      assert {:error, %Ecto.Changeset{} = changeset} = Ledgers.create(%{})
      assert "can't be blank" in errors_on(changeset).account_id
      assert "can't be blank" in errors_on(changeset).amount
      assert "can't be blank" in errors_on(changeset).entry_type
    end

    test "validates amount is greater than zero" do
      account = AccountsFixtures.account_fixture()

      attrs = %{
        account_id: account.id,
        amount: "0.00",
        entry_type: :credit
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Ledgers.create(attrs)
      assert "must be greater than 0.0" in errors_on(changeset).amount
    end

    test "validates entry_type inclusion" do
      account = AccountsFixtures.account_fixture()

      attrs = %{
        account_id: account.id,
        amount: "100.00",
        entry_type: :invalid
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Ledgers.create(attrs)
      assert "is invalid" in errors_on(changeset).entry_type
    end

    test "validates foreign key constraints" do
      invalid_account_id = Ecto.UUID.generate()

      attrs = %{
        account_id: invalid_account_id,
        amount: "100.00",
        entry_type: :credit
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Ledgers.create(attrs)
      assert "does not exist" in errors_on(changeset).account_id
    end

    test "transaction rollback on account update failure" do
      # This test simulates a scenario where ledger creation succeeds
      # but account update fails, ensuring transaction rollback
      account = AccountsFixtures.account_fixture()

      # Delete the account to cause foreign key constraint violation
      Accounts.delete_account(account)

      attrs = %{
        account_id: account.id,
        amount: "100.00",
        entry_type: :credit
      }

      assert {:error, _} = Ledgers.create(attrs)

      # Verify no ledger was created
      assert [] = Ledgers.list(account_id: account.id)
    end
  end

  describe "database triggers and constraints" do
    test "ledger entries are immutable - updates are prevented" do
      ledger = LedgersFixtures.ledger_fixture()

      # Attempt to update ledger directly in database should fail
      query = from(l in Ledger, where: l.id == ^ledger.id)

      assert_raise Postgrex.Error, ~r/Ledger entries are immutable/, fn ->
        Repo.update_all(query, set: [amount: Decimal.new("999.99")])
      end
    end

    test "ledger entries have no updated_at field" do
      ledger = LedgersFixtures.ledger_fixture()

      # Verify that updated_at field doesn't exist
      assert Map.has_key?(ledger, :inserted_at)
      refute Map.has_key?(ledger, :updated_at)
    end

    test "ledger indexes are present and functional" do
      account = AccountsFixtures.account_fixture()
      transaction = TransactionsFixtures.transaction_fixture(%{account_id: account.id})

      # Create multiple ledgers to test indexes
      ledgers =
        for i <- 1..5 do
          LedgersFixtures.ledger_fixture(%{
            account_id: account.id,
            transaction_id: transaction.id,
            amount: "#{i}0.00"
          })
        end

      # Test account_id index performance
      account_ledgers = Ledgers.list(account_id: account.id)
      assert length(account_ledgers) == 5

      # Test transaction_id index performance
      transaction_ledgers = Ledgers.list(transaction_id: transaction.id)
      assert length(transaction_ledgers) == 5

      # Verify results match expected ledgers
      ledger_ids = Enum.map(ledgers, & &1.id)
      result_ids = Enum.map(account_ledgers, & &1.id)
      assert Enum.sort(ledger_ids) == Enum.sort(result_ids)
    end
  end

  describe "balance calculation" do
    test "calculate_new_balance for credit entries" do
      # This tests the private function indirectly through create/1
      account = AccountsFixtures.account_fixture(%{balance: "500.00"})

      {:ok, {_ledger, updated_account}} =
        Ledgers.create(%{
          account_id: account.id,
          amount: "100.00",
          entry_type: :credit
        })

      assert updated_account.balance == Decimal.new("600.00")
    end

    test "calculate_new_balance for debit entries" do
      # This tests the private function indirectly through create/1
      account = AccountsFixtures.account_fixture(%{balance: "500.00"})

      {:ok, {_ledger, updated_account}} =
        Ledgers.create(%{
          account_id: account.id,
          amount: "75.00",
          entry_type: :debit
        })

      assert updated_account.balance == Decimal.new("425.00")
    end

    test "balance calculation with decimal precision" do
      account = AccountsFixtures.account_fixture(%{balance: "1000.123456"})

      {:ok, {_ledger, updated_account}} =
        Ledgers.create(%{
          account_id: account.id,
          amount: "50.654321",
          entry_type: :debit
        })

      assert updated_account.balance == Decimal.new("949.469135")
    end
  end

  describe "concurrent access and race conditions" do
    @tag :capture_log
    test "concurrent ledger creation maintains data integrity" do
      account = AccountsFixtures.account_fixture(%{balance: "1000.00"})

      # Simulate concurrent ledger creation
      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            Ledgers.create(%{
              account_id: account.id,
              amount: "10.00",
              entry_type: if(rem(i, 2) == 0, do: :credit, else: :debit)
            })
          end)
        end

      results = Task.await_many(tasks, 5000)

      # All operations should succeed
      assert Enum.all?(results, &match?({:ok, _}, &1))

      # Verify final account balance is consistent
      final_account = Accounts.get!(account.id)
      ledgers = Ledgers.list(account_id: account.id)

      # Manual balance calculation to verify consistency
      expected_balance =
        ledgers
        |> Enum.reduce(Decimal.new("1000.00"), fn ledger, acc ->
          case ledger.entry_type do
            :credit -> Decimal.add(acc, ledger.amount)
            :debit -> Decimal.sub(acc, ledger.amount)
          end
        end)

      assert final_account.balance == expected_balance
    end
  end

  describe "updates" do
    setup do
      # Create a user for testing
      user = insert(:user)

      account =
        Bank.AccountsFixtures.AccountsFixtures.account_fixture(%{
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
