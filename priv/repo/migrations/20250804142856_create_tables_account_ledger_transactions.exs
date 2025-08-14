defmodule Bank.Repo.Migrations.CreateTablesAccountLedgerTransactions do
  @moduledoc """
  Ecto docs recommends to use ups and downs because change function could fail when using execute.
  """
  use Ecto.Migration

  def change do
    # Enable UUID extension if not exists
    execute("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"")
    #
    # Accounts
    #
    create_if_not_exists table(:accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :account_number, :string, null: false
      add :account_type, :string, null: false
      add :balance, :decimal, precision: 18, scale: 6, default: 0.000000
      add :balance_updated_at, :utc_datetime_usec, default: fragment("NOW()")
      add :currency, :string, null: false, default: "EUR"
      add :metadata, :map, default: %{}
      add :name, :string, null: false
      add :status, :string, null: false, default: "active"
      add :user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:accounts, :account_number)
    create_if_not_exists unique_index(:accounts, [:account_type, :currency, :user_id])
    # Fast lookup to find an active account type
    create_if_not_exists index(:accounts, [:account_type, :status, :user_id])
    # Fast lookup for balance updates
    create_if_not_exists index(:accounts, [:currency, :id])
    # Fast lookup to get the latest balance
    create_if_not_exists index(
                           :accounts,
                           [:id, :currency, {:desc_nulls_last, :balance_updated_at}],
                           include: [:balance],
                           name: :accounts_balance_covering_idx
                         )

    # Fast lookup to list all user accounts
    create_if_not_exists index(:accounts, [:user_id])
    # Trigger for account currency immutability
    execute(
      prevent_account_currency_update_function_up(),
      prevent_account_currency_update_function_down()
    )

    execute(
      prevent_account_currency_update_trigger_up(),
      prevent_account_currency_update_trigger_down()
    )

    #
    # Transactions
    #
    create_if_not_exists table(:transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :amount, :decimal, precision: 18, scale: 6, null: false
      add :currency, :string, null: false
      add :description, :text, null: false
      add :metadata, :map, default: %{}
      add :status, :string, null: false, default: "pending"
      add :transaction_type, :string, null: false
      add :account_id, references(:accounts, type: :binary_id, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime_usec)
    end

    # Fast lookup to find pending, failed, etc transactions by account
    create_if_not_exists index(:transactions, [:account_id, :status])
    # Fast lookup to find pending, failed, etc transactions by account
    create_if_not_exists index(:transactions, [:account_id, :transaction_type])
    # Fast lookup for reporting and analytics
    create_if_not_exists index(:transactions, [:account_id, :transaction_type, :updated_at])
    #
    # Ledgers
    #
    create_if_not_exists table(:ledgers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :amount, :decimal, precision: 18, scale: 6, null: false
      add :entry_type, :string, null: false
      add :account_id, references(:accounts, type: :binary_id, on_delete: :restrict), null: false
      add :transaction_id, references(:transactions, type: :binary_id, on_delete: :restrict)

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create_if_not_exists index(:ledgers, [:account_id, :inserted_at])
    create_if_not_exists index(:ledgers, [:transaction_id])

    # Triggers for ledgers immutability
    execute(
      prevent_ledger_updates_function_up(),
      prevent_ledger_updates_function_down()
    )

    execute(
      prevent_ledger_updates_trigger_up(),
      prevent_ledger_updates_trigger_down()
    )

    #
    # Transactions audit log
    #
    create_if_not_exists table(:transaction_audit_logs) do
      add :transaction_id, :binary_id, null: false
      add :operation, :string, null: false
      add :old_values, :map
      add :new_values, :map
      add :changed_at, :utc_datetime_usec, default: fragment("NOW()")
    end

    create_if_not_exists index(:transaction_audit_logs, [:transaction_id, :changed_at])

    # Triggers for audit logging
    execute(log_transaction_changes_function_up(), log_transaction_changes_function_down())
    execute(log_transaction_changes_trigger_up(), log_transaction_changes_trigger_down())
  end

  #
  # Private functions
  #

  # Execute private functions
  # I do not use &function/0 because that not works when using ecto.migrate.
  defp log_transaction_changes_function_up do
    """
    CREATE OR REPLACE FUNCTION log_transaction_changes()
    RETURNS TRIGGER AS $$
    BEGIN
      IF TG_OP = 'UPDATE' THEN
        INSERT INTO transaction_audit_logs (transaction_id, operation, old_values, new_values)
        VALUES (NEW.id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
      ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO transaction_audit_logs (transaction_id, operation, new_values)
        VALUES (NEW.id, 'INSERT', to_jsonb(NEW));
        RETURN NEW;
      END IF;
      RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;
    """
  end

  defp log_transaction_changes_trigger_up do
    """
    CREATE TRIGGER transaction_audit_trigger
    AFTER INSERT OR UPDATE ON transactions
    FOR EACH ROW
    EXECUTE FUNCTION log_transaction_changes();
    """
  end

  defp log_transaction_changes_function_down,
    do: "DROP FUNCTION IF EXISTS log_transaction_changes();"

  defp log_transaction_changes_trigger_down,
    do: "DROP TRIGGER IF EXISTS transaction_audit_trigger ON transactions;"

  # Prevent account currency update

  defp prevent_account_currency_update_function_up do
    """
    CREATE OR REPLACE FUNCTION prevent_account_currency_update()
    RETURNS TRIGGER AS $$
    BEGIN
      IF NEW.currency <> OLD.currency THEN
        RAISE EXCEPTION 'Currency cannot be updated once set';
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """
  end

  defp prevent_account_currency_update_trigger_up do
    """
    CREATE TRIGGER prevent_account_currency_update_trigger
      BEFORE UPDATE ON accounts
      FOR EACH ROW
      WHEN (OLD.currency IS DISTINCT FROM NEW.currency)
      EXECUTE FUNCTION prevent_account_currency_update();
    """
  end

  defp prevent_account_currency_update_function_down,
    do: "DROP FUNCTION IF EXISTS prevent_account_currency_update()"

  defp prevent_account_currency_update_trigger_down,
    do: "DROP TRIGGER IF EXISTS prevent_account_currency_update_trigger ON accounts;"

  # Prevent ledger updates

  defp prevent_ledger_updates_function_up do
    """
    CREATE OR REPLACE FUNCTION prevent_ledger_updates()
      RETURNS TRIGGER AS $$
      BEGIN
        RAISE EXCEPTION 'Ledger entries are immutable. Updates not allowed.';
        RETURN NULL;
      END;
    $$ LANGUAGE plpgsql;
    """
  end

  defp prevent_ledger_updates_function_down,
    do: "DROP FUNCTION IF EXISTS prevent_ledger_updates();"

  defp prevent_ledger_updates_trigger_up do
    """
    CREATE TRIGGER enforce_ledger_immutability
    BEFORE UPDATE ON ledgers
    FOR EACH ROW
    EXECUTE FUNCTION prevent_ledger_updates();
    """
  end

  defp prevent_ledger_updates_trigger_down,
    do: "DROP TRIGGER IF EXISTS enforce_ledger_immutability ON ledgers;"
end
