defmodule Bank.Accounts.LedgersTest do
  use Bank.DataCase, async: true

  import Ecto.Query

  alias Bank.Accounts
  alias Bank.AccountsFixtures
  alias Bank.Ledgers
  alias Bank.Ledgers.Ledger
  alias Bank.LedgersFixtures
  alias Bank.TransactionsFixtures

  describe "list/1" do
    setup do
      account = AccountsFixtures.fixture()
      transaction = TransactionsFixtures.fixture(%{account_id: account.id})

      ledger_entries =
        LedgersFixtures.multiple_fixture(%{
          account_id: account.id,
          transaction_id: transaction.id
        })

      %{account: account, ledger_entries: ledger_entries, transaction: transaction}
    end

    test "returns all ledgers", %{ledger_entries: ledger} do
      result = Ledgers.list()
      assert length(result) == length(ledger)
    end

    test "filters by account_id", %{account: account, ledger_entries: ledger} do
      other_account = AccountsFixtures.fixture()
      _other_ledger = LedgersFixtures.fixture(%{account_id: other_account.id})
      filters = [{"eq", :account_id, account.id}]

      result = Ledgers.list(filters: filters)
      assert length(ledger) == length(result)
    end

    test "filters by transaction_id", %{
      account: account,
      transaction: transaction,
      ledger_entries: ledger
    } do
      other_transaction =
        TransactionsFixtures.fixture(%{
          account_id: account.id,
          amount: Decimal.new("1234.000000")
        })

      _other_ledger_entry =
        LedgersFixtures.fixture(%{
          account_id: account.id,
          transaction_id: other_transaction.id
        })

      filters = [{"eq", :transaction_id, transaction.id}]

      result = Ledgers.list(filters: filters)
      assert length(ledger) == length(result)
    end

    test "filters by entry_type" do
      filters = [{"eq", :entry_type, :credit}]

      result = Ledgers.list(filters: filters)
      assert length(result) == 2
    end

    test "filters by date range", %{account: account, ledger_entries: ledger} do
      utc = DateTime.utc_now()
      from_date = DateTime.add(utc, -1, :day)
      to_date = utc

      # Create ledger within date range
      # {:ok, {ledger_in_range, _}} =
      #   Ledgers.create(%{
      #     account_id: account.id,
      #     amount: Decimal.new("100.00"),
      #     entry_type: :credit
      #   })

      # Mock a ledger outside date range by updating timestamp
      _ledger_out_of_range =
        LedgersFixtures.fixture(%{
          account_id: account.id,
          inserted_at: DateTime.add(from_date, 1, :day)
        })

      # Repo.update_all(
      #   from(l in Ledger, where: l.id == ^ledger_out_of_range.id),
      #   set: [inserted_at: ~U[2023-01-01 00:00:00Z]]
      # )

      result = Ledgers.list(from_date: from_date, to_date: to_date)
      assert length(result) == length(ledger)
    end

    test "orders by inserted_at desc by default", %{account: account} do
      _ledger1 = LedgersFixtures.fixture(%{account_id: account.id})
      # Ensure different timestamps
      :timer.sleep(10)
      ledger2 = LedgersFixtures.fixture(%{account_id: account.id})

      result = Ledgers.list()
      assert hd(result) == ledger2
    end

    test "supports custom ordering", %{account: account} do
      ledger1 =
        LedgersFixtures.fixture(%{account_id: account.id, amount: Decimal.new("5.000000")})

      _ledger2 =
        LedgersFixtures.fixture(%{account_id: account.id, amount: Decimal.new("100.000000")})

      result = Ledgers.list(order_by: [asc: :amount])

      assert hd(result) == ledger1
    end

    test "supports limit and offset" do
      filters = [{"limit", 5}, {"offset", 2}]

      result = Ledgers.list(filters: filters)
      assert length(result) == 2
    end

    test "preloads associations" do
      [ledger | _] = Ledgers.list(preload: [:account, :transaction])

      assert Ecto.assoc_loaded?(ledger.account)
      assert Ecto.assoc_loaded?(ledger.transaction)
    end
  end

  describe "get!/2" do
    test "returns the ledger with given id" do
      ledger = LedgersFixtures.fixture()
      assert ledger == Ledgers.get!(ledger.id)
    end

    test "raises when ledger not found" do
      assert_raise Ecto.NoResultsError, fn ->
        Ledgers.get!(Ecto.UUID.generate())
      end
    end

    test "preloads associations when requested" do
      account = AccountsFixtures.fixture()
      transaction = TransactionsFixtures.fixture(%{account_id: account.id})

      ledger =
        LedgersFixtures.fixture(%{account_id: account.id, transaction_id: transaction.id})

      result = Ledgers.get!(ledger.id, preload: [:account, :transaction])

      assert Ecto.assoc_loaded?(result.account)
      assert Ecto.assoc_loaded?(result.transaction)
    end
  end

  describe "get_by/2" do
    test "returns ledger matching clauses" do
      amount = "123.450000"

      ledger = LedgersFixtures.fixture(%{amount: Decimal.new(amount)})
      result = Ledgers.get_by(amount: Decimal.new(amount))

      assert ledger == result
    end

    test "preloads associations when requested" do
      account = AccountsFixtures.fixture()
      ledger = LedgersFixtures.fixture(%{account_id: account.id})

      result = Ledgers.get_by([amount: ledger.amount], preload: [:account, :transaction])

      assert Ecto.assoc_loaded?(result.account)
      assert Ecto.assoc_loaded?(result.transaction)
    end
  end

  describe "create/1" do
    setup do
      account = AccountsFixtures.fixture(%{balance: Decimal.new("1000.00")})

      %{account: account}
    end

    test "creates ledger entry and updates account balance for credit", %{account: account} do
      attrs = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        entry_type: :credit
      }

      assert {:ok, {%Ledger{} = ledger, updated_account}} = Ledgers.create(attrs)
      assert ledger.amount == Decimal.new("100.00")
      assert ledger.entry_type == :credit
      assert ledger.account_id == account.id
      assert updated_account.balance == Decimal.new("1100.000000")
    end

    test "creates ledger entry and updates account balance for debit", %{account: account} do
      attrs = %{
        account_id: account.id,
        amount: Decimal.new("50.00"),
        entry_type: :debit
      }

      assert {:ok, {%Ledger{} = ledger, updated_account}} = Ledgers.create(attrs)
      assert ledger.amount == Decimal.new("50.00")
      assert ledger.entry_type == :debit
      assert updated_account.balance == Decimal.new("950.000000")
    end

    test "creates ledger with transaction reference", %{account: account} do
      transaction = TransactionsFixtures.fixture(%{account_id: account.id})

      attrs = %{
        account_id: account.id,
        amount: Decimal.new("75.00"),
        entry_type: :credit,
        transaction_id: transaction.id
      }

      assert {:ok, {%Ledger{} = ledger, _updated_account}} = Ledgers.create(attrs)
      assert ledger.transaction_id == transaction.id
    end

    test "creates ledger with decimal precision" do
      account = AccountsFixtures.fixture(%{balance: "1000.123456"})

      {:ok, {_ledger, updated_account}} =
        Ledgers.create(%{
          account_id: account.id,
          amount: Decimal.new("50.654321"),
          entry_type: :debit
        })

      assert updated_account.balance == Decimal.new("949.469135")
    end
  end

  describe "database triggers and constraints" do
    setup do
      ledger = LedgersFixtures.fixture()

      %{ledger: ledger}
    end

    test "ledger entries are immutable - updates are prevented", %{ledger: ledger} do
      # Attempt to update ledger directly in database should fail
      query = from(l in Ledger, where: l.id == ^ledger.id)

      assert_raise Postgrex.Error, ~r/Ledger entries are immutable/, fn ->
        Repo.update_all(query, set: [amount: Decimal.new("999.99")])
      end
    end

    test "ledger entries have no updated_at field", %{ledger: ledger} do
      assert Map.has_key?(ledger, :inserted_at)
      refute Map.has_key?(ledger, :updated_at)
    end
  end

  describe "concurrent access and race conditions" do
    @tag :capture_log
    test "concurrent ledger creation maintains data integrity" do
      account = AccountsFixtures.fixture(%{balance: "1000.00"})

      # Simulate concurrent ledger creation
      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            Ledgers.create(%{
              account_id: account.id,
              amount: Decimal.new("10.00"),
              entry_type: if(rem(i, 2) == 0, do: :credit, else: :debit)
            })
          end)
        end

      results = Task.await_many(tasks, 5000)

      # All operations should succeed
      assert Enum.all?(results, &match?({:ok, _}, &1))

      # Verify final account balance is consistent
      final_account = Accounts.get!(account.id)
      filters = [{"eq", :account_id, account.id}]
      result = Ledgers.list(filters: filters)

      # Manual balance calculation to verify consistency
      expected_balance =
        result
        |> Enum.reduce(Decimal.new("1000.00"), fn ledger, acc ->
          case ledger.entry_type do
            :credit -> Decimal.add(acc, ledger.amount)
            :debit -> Decimal.sub(acc, ledger.amount)
          end
        end)

      assert final_account.balance == expected_balance
    end
  end

  describe "validations" do
    setup do
      account = AccountsFixtures.fixture()

      %{account: account}
    end

    test "validates required fields" do
      assert {:error, %Ecto.Changeset{} = changeset} = Ledgers.create(%{})
      errors = errors_on(changeset)

      expected_errors = %{
        amount: ["can't be blank"],
        account_id: ["can't be blank"],
        entry_type: ["can't be blank"]
      }

      assert errors == expected_errors
    end

    test "validates amount is greater than zero" do
      account = AccountsFixtures.fixture()

      attrs = %{
        account_id: account.id,
        amount: Decimal.new("0.00"),
        entry_type: :credit
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Ledgers.create(attrs)
      expected_error = %{amount: ["must be greater than 0.0"]}

      assert expected_error == errors_on(changeset)
    end
  end

  # describe "updates" do
  #   setup do
  #     # Create a user for testing
  #     user = insert(:user)

  #     account =
  #       Bank.AccountsFixtures.AccountsFixtures.fixture(%{
  #         user: user,
  #         name: "Ledgers account"
  #       })

  #     {:ok, user: user, account: account}
  #   end

  #   test "ledgers cannot be updated (trigger enforced)" do
  #     ledger = insert!(:ledger, amount: Decimal.new("10.00"))

  #     assert_raise Postgrex.Error, ~r/Ledger entries are immutable/, fn ->
  #       ledger
  #       |> Ecto.Changeset.change(amount: Decimal.new("20.00"))
  #       |> Repo.update()
  #     end
  #   end
  # end
end
