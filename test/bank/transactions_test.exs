defmodule Bank.TransactionsTest do
  use Bank.DataCase, async: true

  alias Bank.Repo
  alias Bank.Transactions
  alias Bank.Transactions.Transaction
  alias Bank.TransactionsFixtures
  alias Bank.UsersFixtures

  describe "list/1" do
    setup do
      account = Bank.AccountsFixtures.fixture()

      # Create multiple transactions with different types and dates
      transactions = TransactionsFixtures.multiple_fixture()

      %{account: account, transactions: transactions}
    end

    test "returns all transactions by default", %{transactions: transactions} do
      result = Transactions.list()
      assert length(result) == length(transactions)
    end

    test "filters by transaction type" do
      filters = [{"eq", :transaction_type, :deposit}]
      result = Transactions.list(filters: filters)

      assert Enum.all?(result, &(&1.transaction_type == :deposit))
    end

    test "orders by updated_at descending by default" do
      result = Transactions.list()

      # Should be sorted by updated_at descending
      sorted_ids = Enum.map(result, & &1.id)

      expected_ids =
        result
        |> Enum.sort(&(DateTime.compare(&1.updated_at, &2.updated_at) != :lt))
        |> Enum.map(& &1.id)

      assert sorted_ids == expected_ids
    end

    test "accepts custom order_by" do
      result = Transactions.list(order_by: [asc: :amount])

      amounts =
        Enum.map(result, fn %{amount: amount} ->
          amount
          |> Decimal.to_string()
          |> String.to_float()
        end)

      sorted_amounts = Enum.sort(amounts)

      assert amounts == sorted_amounts
    end

    test "preloads associations when specified" do
      result = Transactions.list(preload: [:account])

      assert length(result) > 0
      assert Ecto.assoc_loaded?(hd(result).account)
    end
  end

  describe "get!/2" do
    setup do
      transaction = TransactionsFixtures.fixture()

      %{transaction: transaction}
    end

    test "returns transaction when exists", %{transaction: transaction} do
      result = Transactions.get!(transaction.id)
      assert result.id == transaction.id
    end

    test "raises when transaction doesn't exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Transactions.get!(Ecto.UUID.generate())
      end
    end

    test "preloads associations when specified", %{transaction: transaction} do
      result = Transactions.get!(transaction.id, preload: [:account])
      assert Ecto.assoc_loaded?(result.account)
    end
  end

  describe "get_by/2" do
    setup do
      transaction =
        TransactionsFixtures.fixture(%{
          description: "Unique description for get_by"
        })

      %{transaction: transaction}
    end

    test "returns transaction when found", %{transaction: transaction} do
      result = Transactions.get_by(description: "Unique description for get_by")
      assert result.id == transaction.id
    end

    test "returns nil when not found" do
      result = Transactions.get_by(%{description: "Non-existent description"})
      assert is_nil(result)
    end

    test "preloads associations when specified", %{transaction: transaction} do
      result =
        Transactions.get_by(
          %{id: transaction.id},
          preload: [:account]
        )

      assert Ecto.assoc_loaded?(result.account)
    end
  end

  describe "create/1" do
    setup do
      user = UsersFixtures.fixture()
      account = Bank.AccountsFixtures.fixture(%{user: user})

      %{account: account}
    end

    test "creates transaction with valid attributes", %{account: account} do
      attrs = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        currency: "USD",
        description: "Test transaction",
        transaction_type: :deposit
      }

      assert {:ok, %Transaction{} = transaction} = Transactions.create(attrs)
      assert transaction.amount == Decimal.new("100.00")
      assert transaction.currency == "USD"
      assert transaction.description == "Test transaction"
      assert transaction.transaction_type == :deposit
      assert transaction.status == :pending
    end

    test "creates transaction with metadata", %{account: account} do
      metadata = %{
        initiated_by_type: :user,
        origin_external: "stripe"
      }

      attrs = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        currency: "USD",
        description: "Transaction with metadata",
        transaction_type: :deposit,
        metadata: metadata
      }

      {:ok, transaction} = Transactions.create(attrs)
      assert transaction.metadata.initiated_by_type == :user
      assert transaction.metadata.origin_external == "stripe"
    end

    test "returns error for invalid attributes" do
      attrs = %{
        amount: Decimal.new("-100.00"),
        currency: "INVALID",
        description: "",
        transaction_type: :invalid_type
      }

      assert {:error, changeset} = Transactions.create(attrs)
      errors = errors_on(changeset)

      expected_errors = %{
        description: ["can't be blank"],
        currency: ["should be 3 character(s)"],
        amount: ["must be greater than 0.0"],
        account_id: ["can't be blank"],
        transaction_type: ["is invalid"]
      }

      assert expected_errors == errors
    end
  end

  describe "complete/2" do
    setup do
      transaction = TransactionsFixtures.fixture(%{status: :pending})

      %{transaction: transaction}
    end

    test "completes transaction successfully", %{transaction: transaction} do
      account_before = Repo.get!(Bank.Accounts.Account, transaction.account_id)
      balance_before = account_before.balance

      assert {:ok, {updated_transaction, ledger, account_after}} =
               Transactions.complete(transaction)

      assert updated_transaction.status == :completed
      assert not is_nil(updated_transaction.metadata.completed_at)
      assert updated_transaction.metadata.completed_by == "system"

      # Verify ledger entry was created
      assert ledger.transaction_id == transaction.id
      assert ledger.account_id == transaction.account_id
      assert ledger.amount == transaction.amount

      # Verify account balance was updated
      assert account_after.balance != balance_before
    end

    test "completes with custom metadata", %{transaction: transaction} do
      custom_metadata = %{completed_by: "admin_user_123"}

      assert {:ok, {updated_transaction, _ledger, _account}} =
               Transactions.complete(transaction, custom_metadata)

      assert updated_transaction.metadata.completed_by == "admin_user_123"
    end

    test "creates credit ledger entry for deposits", %{} do
      deposit_transaction =
        TransactionsFixtures.fixture(%{
          transaction_type: :deposit,
          status: :pending
        })

      {:ok, {_transaction, ledger, _account}} = Transactions.complete(deposit_transaction)
      assert ledger.entry_type == :credit
    end

    test "creates debit ledger entry for withdrawals", %{} do
      withdrawal_transaction =
        TransactionsFixtures.fixture(%{
          transaction_type: :withdrawal,
          status: :pending
        })

      {:ok, {_transaction, ledger, _account}} = Transactions.complete(withdrawal_transaction)
      assert ledger.entry_type == :debit
    end

    test "creates credit ledger entry for interest payments", %{} do
      interest_transaction =
        TransactionsFixtures.fixture(%{
          transaction_type: :interest_payment,
          status: :pending
        })

      {:ok, {_transaction, ledger, _account}} = Transactions.complete(interest_transaction)
      assert ledger.entry_type == :credit
    end

    test "transaction completion is atomic" do
      transaction = TransactionsFixtures.fixture(%{status: :pending})

      # Mock failure in ledger creation by making account_id invalid
      invalid_transaction = %{transaction | account_id: Ecto.UUID.generate()}

      assert {:error, _changeset} = Transactions.complete(invalid_transaction)

      # Verify original transaction wasn't updated
      reloaded = Repo.get!(Transaction, transaction.id)
      assert reloaded.status == :pending
    end
  end

  describe "fail/4" do
    setup do
      transaction = TransactionsFixtures.fixture(%{status: :pending})

      %{transaction: transaction}
    end

    test "fails transaction with reason", %{transaction: transaction} do
      reason = "Insufficient funds"

      assert {:ok, failed_transaction} = Transactions.fail(transaction, reason)

      assert failed_transaction.status == :failed
      assert failed_transaction.metadata.failure_reason == reason
      assert not is_nil(failed_transaction.metadata.failed_at)
      assert is_nil(failed_transaction.metadata.failure_code)
    end

    test "fails transaction with reason and error code", %{transaction: transaction} do
      reason = "Card declined"
      error_code = "E4001"

      assert {:ok, failed_transaction} = Transactions.fail(transaction, reason, error_code)

      assert failed_transaction.status == :failed
      assert failed_transaction.metadata.failure_reason == reason
      assert failed_transaction.metadata.failure_code == error_code
      assert not is_nil(failed_transaction.metadata.failed_at)
    end

    test "fails transaction with custom metadata", %{transaction: transaction} do
      reason = "Network error"
      custom_metadata = %{origin_external: "stripe"}

      assert {:ok, failed_transaction} =
               Transactions.fail(transaction, reason, nil, custom_metadata)

      assert failed_transaction.metadata.failure_reason == reason
      assert failed_transaction.metadata.origin_external == "stripe"
    end
  end

  describe "update_transaction/2" do
    setup do
      transaction = TransactionsFixtures.fixture()

      %{transaction: transaction}
    end

    test "updates transaction successfully", %{transaction: transaction} do
      new_description = "Updated description"

      assert {:ok, updated_transaction} =
               Transactions.update_transaction(transaction, %{description: new_description})

      assert updated_transaction.description == new_description
    end

    test "returns error for invalid updates", %{transaction: transaction} do
      invalid_attrs = %{amount: Decimal.new("-100.00")}

      assert {:error, %Ecto.Changeset{}} =
               Transactions.update_transaction(transaction, invalid_attrs)
    end
  end

  describe "update_status/2" do
    setup do
      transaction = TransactionsFixtures.fixture(%{status: :pending})

      %{transaction: transaction}
    end

    test "updates status successfully", %{transaction: transaction} do
      assert {:ok, updated_transaction} =
               Transactions.update_status(transaction, :processing)

      assert updated_transaction.status == :processing
    end

    test "returns error for invalid status", %{transaction: transaction} do
      assert {:error, %Ecto.Changeset{}} =
               Transactions.update_status(transaction, :invalid_status)
    end
  end

  describe "duplicate_transaction_validation" do
    setup do
      account = Bank.AccountsFixtures.fixture()

      %{account: account}
    end

    test "prevents duplicate transactions with same criteria", %{account: account} do
      attrs = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        currency: "USD",
        transaction_type: :deposit,
        description: "First transaction"
      }

      {:ok, _first_transaction} = Transactions.create(attrs)

      duplicate_attrs = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        currency: "USD",
        transaction_type: :deposit,
        # Different description (should be ignored)
        description: "Different description"
      }

      {:error, changeset} = Transactions.create(duplicate_attrs)
      assert "duplicated transaction" in errors_on(changeset).id
    end

    test "allows creation after original becomes non-pending/processing", %{account: account} do
      attrs = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        currency: "USD",
        transaction_type: :deposit,
        description: "Test transaction"
      }

      {:ok, original} = Transactions.create(attrs)

      # Test each finished status
      finished_statuses = [:completed, :failed, :cancelled]

      Enum.each(finished_statuses, fn status ->
        # Update to finished status
        {:ok, _transaction} = Transactions.update_status(original, status)

        # Should allow duplicate now
        {:ok, new_transaction} = Transactions.create(attrs)
        assert new_transaction.id != original.id

        # Clean up for next iteration
        Repo.delete!(new_transaction)
        {:ok, _} = Transactions.update_status(original, :pending)
      end)
    end

    test "validates uniqueness across exact field combinations only", %{account: account} do
      base_transaction = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        currency: "USD",
        transaction_type: :deposit,
        description: "Base transaction"
      }

      {:ok, _} = Transactions.create(base_transaction)

      # These should be allowed (different in at least one key field)
      allowed_variations = [
        %{base_transaction | amount: Decimal.new("100.01")},
        %{base_transaction | currency: "EUR"},
        %{base_transaction | transaction_type: :withdrawal}
      ]

      # Create other account for account_id variation
      other_account = Bank.AccountsFixtures.fixture()

      allowed_variations = [
        %{base_transaction | account_id: other_account.id} | allowed_variations
      ]

      Enum.each(allowed_variations, fn attrs ->
        {:ok, transaction} = Transactions.create(attrs)
        assert not is_nil(transaction.id)
      end)
    end

    test "duplicate validation considers only core identifying fields" do
      account = Bank.AccountsFixtures.fixture()

      base_attrs = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        currency: "USD",
        transaction_type: :deposit,
        description: "Original description"
      }

      {:ok, _original} = Transactions.create(base_attrs)

      # Fields that should NOT affect duplicate detection
      non_identifying_variations = [
        %{base_attrs | description: "Completely different description"},
        Map.put(base_attrs, :metadata, %{origin_external: "stripe"}),
        Map.delete(base_attrs, :description)
      ]

      Enum.each(non_identifying_variations, fn attrs ->
        {:error, changeset} = Transactions.create(attrs)
        assert "duplicated transaction" in errors_on(changeset).id
      end)
    end
  end

  describe "performance considerations" do
    test "list with filters uses database indexes efficiently" do
      # Create transactions with known patterns
      account = Bank.AccountsFixtures.fixture()
      expected_time_ms = 10

      1..10
      |> Enum.each(fn i ->
        TransactionsFixtures.fixture(%{
          account_id: account.id,
          transaction_type: if(rem(i, 2) == 0, do: :deposit, else: :withdrawal),
          amount: Decimal.new("#{i * 10}.00")
        })
      end)

      # Filter by account_id and transaction_type - should use composite index
      filters = [
        {"eq", :account_id, account.id},
        {"eq", :transaction_type, :deposit}
      ]

      start_time = System.monotonic_time()
      results = Transactions.list(filters: filters)
      end_time = System.monotonic_time()

      # Should return expected results
      assert length(results) == 5
      assert Enum.all?(results, &(&1.transaction_type == :deposit))

      # Should execute quickly (< 50ms for this small dataset in CI environments)
      execution_time_ms = System.convert_time_unit(end_time - start_time, :native, :millisecond)

      # Allow generous margin for CI environments
      assert execution_time_ms < expected_time_ms
    end

    test "duplicate validation performs efficiently with large datasets" do
      account = Bank.AccountsFixtures.fixture()
      expected_time_ms = 20

      # Create many transactions to test query performance
      1..50
      |> Enum.each(fn i ->
        TransactionsFixtures.fixture(%{
          account_id: account.id,
          amount: Decimal.new("#{i}.00"),
          transaction_type: :deposit,
          # Use completed to avoid duplicate conflicts
          status: :completed
        })
      end)

      # Test duplicate validation performance
      attrs = %{
        account_id: account.id,
        # Unique amount
        amount: Decimal.new("999.00"),
        currency: "USD",
        transaction_type: :deposit,
        description: "Performance test"
      }

      start_time = System.monotonic_time()
      {:ok, _transaction} = Transactions.create(attrs)
      end_time = System.monotonic_time()

      # Should complete quickly even with many existing transactions
      execution_time_ms = System.convert_time_unit(end_time - start_time, :native, :millisecond)

      # Should use indexes effectively
      assert execution_time_ms < expected_time_ms
    end
  end

  describe "edge_cases_and_error_handling" do
    test "duplicate validation works with decimal precision differences" do
      account = Bank.AccountsFixtures.fixture()

      attrs1 = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        currency: "USD",
        transaction_type: :deposit,
        description: "Precision test"
      }

      {:ok, _transaction1} = Transactions.create(attrs1)

      # Test with same decimal value but different precision
      attrs2 = %{
        account_id: account.id,
        # More precision, same value
        amount: Decimal.new("100.000"),
        currency: "USD",
        transaction_type: :deposit,
        description: "Different precision"
      }

      # Should detect as duplicate (Decimal.equal?/2)
      {:error, changeset} = Transactions.create(attrs2)
      assert "duplicated transaction" in errors_on(changeset).id
    end

    test "duplicate validation is case sensitive for currency" do
      account = Bank.AccountsFixtures.fixture()

      attrs1 = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        currency: "usd",
        transaction_type: :deposit,
        description: "Case test"
      }

      {:ok, _transaction1} = Transactions.create(attrs1)

      attrs2 = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        currency: "USD",
        transaction_type: :deposit,
        description: "Case test"
      }

      # Should be allowed (different currency)
      {:ok, transaction2} = Transactions.create(attrs2)
      assert not is_nil(transaction2.id)
    end
  end
end
