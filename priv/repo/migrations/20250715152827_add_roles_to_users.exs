defmodule Bank.Repo.Migrations.AddRolesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Create two different migrations to add default value after creating the column is not necessary
      # because it is a new column and also is automatically managed by postgres >=11
      add_if_not_exists :roles, {:array, :string}, default: ["user"], null: false
    end
  end
end
