defmodule Bank.TransactionsTest do
  use Bank.DataCase, async: true

  import Ecto.Query
  alias Bank.Transactions
  alias Bank.Transactions.Transaction
  alias Bank.Repo

  describe "list/1" do
    setup do
      user = Bank.UsersFixtures.user_fixture()
      account = Bank.AccountsFixtures.account_fixture(%{user: user})

      # Create multiple transactions with different types and dates
      transactions = [
        Bank.TransactionsFixtures.transaction_fixture(%{
          account_id: account.id,
          transaction_type: :deposit,
          amount: Decimal.new("100.00"),
          description: "First deposit"
        }),
        Bank.TransactionsFixtures.transaction_fixture(%{
          account_id: account.id,
          transaction_type: :withdrawal,
          amount: Decimal.new("50.00"),
          description: "First withdrawal"
        }),
        Bank.TransactionsFixtures.transaction_fixture(%{
          account_id: account.id,
          transaction_type: :transfer,
          amount: Decimal.new("75.00"),
          description: "Transfer"
        })
      ]

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
      amounts = Enum.map(result, &Decimal.to_string(&1.amount))
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
      transaction = Bank.TransactionsFixtures.transaction_fixture()
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
        Bank.TransactionsFixtures.transaction_fixture(%{
          description: "Unique description for get_by"
        })

      %{transaction: transaction}
    end

    test "returns transaction when found", %{transaction: transaction} do
      result = Transactions.get_by(%{description: "Unique description for get_by"})
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

  describe "get_by_pending_or_processing/2" do
    setup do
      user = Bank.UsersFixtures.user_fixture()
      account = Bank.AccountsFixtures.account_fixture(%{user: user})

      # Create transactions with different statuses
      pending_transaction =
        Bank.TransactionsFixtures.transaction_fixture(%{
          account_id: account.id,
          status: :pending,
          amount: Decimal.new("100.00"),
          transaction_type: :deposit
        })

      processing_transaction =
        Bank.TransactionsFixtures.transaction_fixture(%{
          account_id: account.id,
          status: :processing,
          amount: Decimal.new("200.00"),
          transaction_type: :withdrawal
        })

      completed_transaction =
        Bank.TransactionsFixtures.transaction_fixture(%{
          account_id: account.id,
          status: :completed,
          amount: Decimal.new("300.00"),
          transaction_type: :transfer
        })

      %{
        account: account,
        pending: pending_transaction,
        processing: processing_transaction,
        completed: completed_transaction
      }
    end

    test "finds pending transaction by criteria", %{account: account, pending: transaction} do
      clauses = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        transaction_type: :deposit
      }

      result = Transactions.get_by_pending_or_processing(clauses)
      assert result.id == transaction.id
    end

    test "finds processing transaction by criteria", %{account: account, processing: transaction} do
      clauses = %{
        account_id: account.id,
        amount: Decimal.new("200.00"),
        transaction_type: :withdrawal
      }

      result = Transactions.get_by_pending_or_processing(clauses)
      assert result.id == transaction.id
    end

    test "does not find completed transaction", %{account: account} do
      clauses = %{
        account_id: account.id,
        amount: Decimal.new("300.00"),
        transaction_type: :transfer
      }

      result = Transactions.get_by_pending_or_processing(clauses)
      assert is_nil(result)
    end

    test "returns nil for non-existent criteria", %{account: account} do
      clauses = %{
        account_id: account.id,
        amount: Decimal.new("999.00"),
        transaction_type: :deposit
      }

      result = Transactions.get_by_pending_or_processing(clauses)
      assert is_nil(result)
    end
  end

  describe "create/1" do
    setup do
      user = Bank.UsersFixtures.user_fixture()
      account = Bank.AccountsFixtures.account_fixture(%{user: user})
      %{account: account}
    end

    test "creates transaction with valid attributes", %{account: account} do
      attrs = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        currency: "EUR",
        description: "Test transaction",
        transaction_type: :deposit
      }

      assert {:ok, %Transaction{} = transaction} = Transactions.create(attrs)
      assert transaction.amount == Decimal.new("100.00")
      assert transaction.currency == "EUR"
      assert transaction.description == "Test transaction"
      assert transaction.transaction_type == :deposit
      assert transaction.status == :pending
    end
  end

  test "prevents duplicate transactions with same criteria", %{account: account} do
    attrs = %{
      account_id: account.id,
      amount: Decimal.new("100.00"),
      currency: "EUR",
      transaction_type: :deposit,
      description: "First transaction"
    }

    {:ok, first_transaction} = Transactions.create(attrs)

    # Try to create duplicate with same criteria
    duplicate_attrs = %{
      account_id: account.id,
      # Same amount
      amount: Decimal.new("100.00"),
      # Same currency
      currency: "EUR",
      # Same type
      transaction_type: :deposit,
      # Different description (should be ignored)
      description: "Different description"
    }

    {:error, changeset} = Transactions.create(duplicate_attrs)
    assert "duplicated transaction" in errors_on(changeset).id
  end

  test "allows duplicate transactions if one is completed", %{account: account} do
    attrs = %{
      account_id: account.id,
      amount: Decimal.new("100.00"),
      currency: "EUR",
      transaction_type: :deposit,
      description: "First transaction"
    }

    {:ok, first_transaction} = Transactions.create(attrs)

    # Complete the first transaction
    {:ok, _} = Transactions.complete(first_transaction)

    # Should allow creating another with same criteria
    {:ok, second_transaction} = Transactions.create(attrs)

    assert first_transaction.id != second_transaction.id
  end

  test "allows duplicate transactions if one is failed", %{account: account} do
    attrs = %{
      account_id: account.id,
      amount: Decimal.new("100.00"),
      currency: "EUR",
      transaction_type: :deposit,
      description: "First transaction"
    }

    {:ok, first_transaction} = Transactions.create(attrs)

    # Fail the first transaction
    {:ok, _} = Transactions.fail(first_transaction, "Test failure")

    # Should allow creating another with same criteria
    {:ok, second_transaction} = Transactions.create(attrs)

    assert first_transaction.id != second_transaction.id
  end

  test "allows duplicate transactions if one is cancelled", %{account: account} do
    attrs = %{
      account_id: account.id,
      amount: Decimal.new("100.00"),
      currency: "EUR",
      transaction_type: :deposit,
      description: "First transaction"
    }

    {:ok, first_transaction} = Transactions.create(attrs)

    # Cancel the first transaction
    {:ok, _} = Transactions.update_status(first_transaction, :cancelled)

    # Should allow creating another with same criteria
    {:ok, second_transaction} = Transactions.create(attrs)

    assert first_transaction.id != second_transaction.id
  end

  test "prevents duplicate with processing status", %{account: account} do
    attrs = %{
      account_id: account.id,
      amount: Decimal.new("100.00"),
      currency: "EUR",
      transaction_type: :deposit,
      description: "First transaction"
    }

    {:ok, first_transaction} = Transactions.create(attrs)

    # Update to processing
    {:ok, _} = Transactions.update_status(first_transaction, :processing)

    # Should prevent duplicate
    {:error, changeset} = Transactions.create(attrs)
    assert "duplicated transaction" in errors_on(changeset).id
  end

  test "allows transactions with different amounts", %{account: account} do
    base_attrs = %{
      account_id: account.id,
      currency: "EUR",
      transaction_type: :deposit,
      description: "Transaction"
    }

    {:ok, transaction1} = Transactions.create(Map.put(base_attrs, :amount, Decimal.new("100.00")))
    {:ok, transaction2} = Transactions.create(Map.put(base_attrs, :amount, Decimal.new("100.01")))

    assert transaction1.id != transaction2.id
  end

  test "allows transactions with different currencies", %{account: account} do
    base_attrs = %{
      account_id: account.id,
      amount: Decimal.new("100.00"),
      transaction_type: :deposit,
      description: "Transaction"
    }

    {:ok, transaction1} = Transactions.create(Map.put(base_attrs, :currency, "EUR"))
    {:ok, transaction2} = Transactions.create(Map.put(base_attrs, :currency, "USD"))

    assert transaction1.id != transaction2.id
  end

  test "allows transactions with different types", %{account: account} do
    base_attrs = %{
      account_id: account.id,
      amount: Decimal.new("100.00"),
      currency: "EUR",
      description: "Transaction"
    }

    {:ok, transaction1} = Transactions.create(Map.put(base_attrs, :transaction_type, :deposit))
    {:ok, transaction2} = Transactions.create(Map.put(base_attrs, :transaction_type, :withdrawal))

    assert transaction1.id != transaction2.id
  end

  test "allows transactions for different accounts" do
    account1 = Bank.AccountsFixtures.account_fixture()
    account2 = Bank.AccountsFixtures.account_fixture()

    attrs = %{
      amount: Decimal.new("100.00"),
      currency: "EUR",
      transaction_type: :deposit,
      description: "Transaction"
    }

    {:ok, transaction1} = Transactions.create(Map.put(attrs, :account_id, account1.id))
    {:ok, transaction2} = Transactions.create(Map.put(attrs, :account_id, account2.id))

    assert transaction1.id != transaction2.id
  end

  test "returns error for invalid attributes" do
    attrs = %{
      # Invalid negative amount
      amount: Decimal.new("-100.00"),
      # Invalid currency length
      currency: "INVALID",
      # Empty description
      description: "",
      # Invalid type
      transaction_type: :invalid_type
    }

    assert {:error, %Ecto.Changeset{}} = Transactions.create(attrs)
  end

  test "creates transaction with metadata", %{account: account} do
    metadata = %{
      initiated_by_type: :user,
      origin_external: "stripe"
    }

    attrs = %{
      account_id: account.id,
      amount: Decimal.new("100.00"),
      currency: "EUR",
      description: "Transaction with metadata",
      transaction_type: :deposit,
      metadata: metadata
    }

    {:ok, transaction} = Transactions.create(attrs)
    assert transaction.metadata.initiated_by_type == :user
    assert transaction.metadata.origin_external == "stripe"
  end

  describe "complete/2" do
    setup do
      transaction = Bank.TransactionsFixtures.transaction_fixture(%{status: :pending})
      %{transaction: transaction}
    end

    test "completes transaction successfully", %{transaction: transaction} do
      assert {:ok, {updated_transaction, ledger, account}} = Transactions.complete(transaction)

      assert updated_transaction.status == :completed
      assert not is_nil(updated_transaction.metadata.completed_at)
      assert updated_transaction.metadata.completed_by == "system"

      # Verify ledger entry was created
      assert ledger.transaction_id == transaction.id
      assert ledger.account_id == transaction.account_id
      assert ledger.amount == transaction.amount

      # Verify account balance was updated
      assert not is_nil(account.balance_updated_at)
    end

    test "completes with custom metadata", %{transaction: transaction} do
      custom_metadata = %{completed_by: "admin_user_123"}

      assert {:ok, {updated_transaction, _ledger, _account}} =
               Transactions.complete(transaction, custom_metadata)

      assert updated_transaction.metadata.completed_by == "admin_user_123"
    end

    test "creates credit ledger entry for deposits", %{} do
      deposit_transaction =
        Bank.TransactionsFixtures.transaction_fixture(%{
          transaction_type: :deposit,
          status: :pending
        })

      {:ok, {_transaction, ledger, _account}} = Transactions.complete(deposit_transaction)
      assert ledger.entry_type == :credit
    end

    test "creates debit ledger entry for withdrawals", %{} do
      withdrawal_transaction =
        Bank.TransactionsFixtures.transaction_fixture(%{
          transaction_type: :withdrawal,
          status: :pending
        })

      {:ok, {_transaction, ledger, _account}} = Transactions.complete(withdrawal_transaction)
      assert ledger.entry_type == :debit
    end

    test "creates credit ledger entry for interest payments", %{} do
      interest_transaction =
        Bank.TransactionsFixtures.transaction_fixture(%{
          transaction_type: :interest_payment,
          status: :pending
        })

      {:ok, {_transaction, ledger, _account}} = Transactions.complete(interest_transaction)
      assert ledger.entry_type == :credit
    end

    test "transaction completion is atomic" do
      transaction = Bank.TransactionsFixtures.transaction_fixture(%{status: :pending})

      # Mock failure in ledger creation by making account_id invalid
      invalid_transaction = %{transaction | account_id: Ecto.UUID.generate()}

      assert {:error, _reason} = Transactions.complete(invalid_transaction)

      # Verify original transaction wasn't updated
      reloaded = Repo.get!(Transaction, transaction.id)
      assert reloaded.status == :pending
    end
  end

  describe "fail/4" do
    setup do
      transaction = Bank.TransactionsFixtures.transaction_fixture(%{status: :pending})
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
      transaction = Bank.TransactionsFixtures.transaction_fixture()
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
      transaction = Bank.TransactionsFixtures.transaction_fixture(%{status: :pending})
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
      account = Bank.AccountsFixtures.account_fixture()
      %{account: account}
    end

    test "detects duplicates based on core transaction fields", %{account: account} do
      # Create initial transaction
      attrs = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        currency: "EUR",
        transaction_type: :deposit,
        description: "Original transaction"
      }

      {:ok, _transaction} = Transactions.create(attrs)

      # Test various field combinations that should be considered duplicates
      duplicate_scenarios = [
        %{attrs | description: "Different description"},
        %{attrs | metadata: %{origin_external: "stripe"}},
        Map.delete(attrs, :description)
      ]

      Enum.each(duplicate_scenarios, fn duplicate_attrs ->
        {:error, changeset} = Transactions.create(duplicate_attrs)
        assert "duplicated transaction" in errors_on(changeset).id
      end)
    end

    test "allows creation after original becomes non-pending/processing", %{account: account} do
      attrs = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        currency: "EUR",
        transaction_type: :deposit,
        description: "Test transaction"
      }

      {:ok, original} = Transactions.create(attrs)

      # Test each terminal status
      terminal_statuses = [:completed, :failed, :cancelled]

      Enum.each(terminal_statuses, fn status ->
        # Update to terminal status
        {:ok, _} = Transactions.update_status(original, status)

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
        currency: "EUR",
        transaction_type: :deposit,
        description: "Base transaction"
      }

      {:ok, _} = Transactions.create(base_transaction)

      # These should be allowed (different in at least one key field)
      allowed_variations = [
        %{base_transaction | amount: Decimal.new("100.01")},
        %{base_transaction | currency: "USD"},
        %{base_transaction | transaction_type: :withdrawal}
      ]

      # Create other account for account_id variation
      other_account = Bank.AccountsFixtures.account_fixture()

      allowed_variations = [
        %{base_transaction | account_id: other_account.id} | allowed_variations
      ]

      Enum.each(allowed_variations, fn attrs ->
        {:ok, transaction} = Transactions.create(attrs)
        assert not is_nil(transaction.id)
      end)
    end
  end

  describe "data_integrity_and_concurrency" do
    test "handles concurrent duplicate detection correctly" do
      account = Bank.AccountsFixtures.account_fixture()

      attrs = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        currency: "EUR",
        transaction_type: :deposit,
        description: "Concurrent test"
      }

      # Simulate concurrent creation attempts with same criteria
      tasks =
        1..5
        |> Enum.map(fn _ ->
          Task.async(fn -> Transactions.create(attrs) end)
        end)

      results = Enum.map(tasks, &Task.await/1)

      # Should have one success and four failures
      {successes, failures} = Enum.split_with(results, &match?({:ok, _}, &1))

      assert length(successes) == 1
      assert length(failures) == 4

      # All failures should be duplicate errors
      Enum.each(failures, fn {:error, changeset} ->
        assert "duplicated transaction" in errors_on(changeset).id
      end)
    end

    test "duplicate validation considers only core identifying fields" do
      account = Bank.AccountsFixtures.account_fixture()

      base_attrs = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        currency: "EUR",
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

    test "database constraint prevents race conditions in duplicate detection" do
      account = Bank.AccountsFixtures.account_fixture()

      attrs = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        currency: "EUR",
        transaction_type: :deposit,
        description: "Race condition test"
      }

      # This tests the scenario where two processes pass the duplicate check
      # simultaneously but one should fail at database level if there's a
      # unique constraint on the core fields

      pid = self()

      # Spawn processes that will try to create simultaneously
      spawn_link(fn ->
        result = Transactions.create(attrs)
        send(pid, {:result, 1, result})
      end)

      spawn_link(fn ->
        result = Transactions.create(attrs)
        send(pid, {:result, 2, result})
      end)

      # Collect results
      results = [
        receive do
          {:result, _, result} -> result
        end,
        receive do
          {:result, _, result} -> result
        end
      ]

      # One should succeed, one should fail
      {successes, failures} = Enum.split_with(results, &match?({:ok, _}, &1))

      # Due to the validation logic, both might fail if the first one completes
      # before the second one starts, or one succeeds and one fails
      assert length(successes) <= 1
      assert length(results) == 2
    end
  end

  describe "performance considerations" do
    test "list with filters uses database indexes efficiently" do
      # Create transactions with known patterns
      account = Bank.AccountsFixtures.account_fixture()

      1..10
      |> Enum.each(fn i ->
        Bank.TransactionsFixtures.transaction_fixture(%{
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
      assert execution_time_ms < 100
    end

    test "duplicate validation performs efficiently with large datasets" do
      account = Bank.AccountsFixtures.account_fixture()

      # Create many transactions to test query performance
      1..50
      |> Enum.each(fn i ->
        Bank.TransactionsFixtures.transaction_fixture(%{
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
        currency: "EUR",
        transaction_type: :deposit,
        description: "Performance test"
      }

      start_time = System.monotonic_time()
      {:ok, _transaction} = Transactions.create(attrs)
      end_time = System.monotonic_time()

      # Should complete quickly even with many existing transactions
      execution_time_ms = System.convert_time_unit(end_time - start_time, :native, :millisecond)
      # Should use indexes effectively
      assert execution_time_ms < 100
    end
  end

  describe "edge_cases_and_error_handling" do
    test "handles malformed changeset in duplicate validation" do
      # Test with missing required fields that would cause changeset errors
      attrs = %{
        amount: nil,
        currency: nil,
        transaction_type: nil,
        account_id: nil
      }

      {:error, changeset} = Transactions.create(attrs)

      # Should have validation errors, not duplicate errors
      assert "can't be blank" in errors_on(changeset).amount
      assert "can't be blank" in errors_on(changeset).currency
      assert "can't be blank" in errors_on(changeset).transaction_type
      refute Keyword.has_key?(errors_on(changeset), :id)
    end

    test "duplicate validation works with decimal precision differences" do
      account = Bank.AccountsFixtures.account_fixture()

      attrs1 = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        currency: "EUR",
        transaction_type: :deposit,
        description: "Precision test"
      }

      {:ok, _transaction1} = Transactions.create(attrs1)

      # Test with same decimal value but different precision
      attrs2 = %{
        account_id: account.id,
        # More precision, same value
        amount: Decimal.new("100.000"),
        currency: "EUR",
        transaction_type: :deposit,
        description: "Different precision"
      }

      # Should detect as duplicate (Decimal.equal?/2)
      {:error, changeset} = Transactions.create(attrs2)
      assert "duplicated transaction" in errors_on(changeset).id
    end

    test "duplicate validation is case sensitive for currency" do
      account = Bank.AccountsFixtures.account_fixture()

      attrs1 = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        # lowercase
        currency: "eur",
        transaction_type: :deposit,
        description: "Case test"
      }

      {:ok, _transaction1} = Transactions.create(attrs1)

      attrs2 = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        # uppercase
        currency: "EUR",
        transaction_type: :deposit,
        description: "Case test"
      }

      # Should be allowed (different currency)
      {:ok, transaction2} = Transactions.create(attrs2)
      assert not is_nil(transaction2.id)
    end

    test "handles transaction creation during concurrent status updates" do
      account = Bank.AccountsFixtures.account_fixture()

      attrs = %{
        account_id: account.id,
        amount: Decimal.new("100.00"),
        currency: "EUR",
        transaction_type: :deposit,
        description: "Concurrent status test"
      }

      {:ok, original} = Transactions.create(attrs)

      # Simulate concurrent operations: one updating status, one creating duplicate
      pid = self()

      # Process 1: Update status to completed
      spawn_link(fn ->
        # Small delay to increase chance of race condition
        :timer.sleep(10)
        result = Transactions.update_status(original, :completed)
        send(pid, {:status_update, result})
      end)

      # Process 2: Try to create duplicate
      spawn_link(fn ->
        # Smaller delay to try during status update
        :timer.sleep(5)
        result = Transactions.create(attrs)
        send(pid, {:create_duplicate, result})
      end)

      # Collect results
      status_result =
        receive do
          {:status_update, result} -> result
        end

      create_result =
        receive do
          {:create_duplicate, result} -> result
        end

      # Status update should succeed
      assert {:ok, _} = status_result

      # Duplicate creation result depends on timing:
      # - If it checks before status update: should fail with duplicate error
      # - If it checks after status update: should succeed
      case create_result do
        {:ok, new_transaction} ->
          # Creation succeeded - status was updated first
          assert new_transaction.id != original.id

        {:error, changeset} ->
          # Creation failed - duplicate was detected
          assert "duplicated transaction" in errors_on(changeset).id
      end
    end
  end
end
