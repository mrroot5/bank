defmodule :"Elixir.Bank.Repo.Migrations.Refactor-transactions" do
  use Ecto.Migration

  def change do
    rename table("transactions"), :description, to: :concept

    alter table("transactions") do
      add :destination, :string, null: false
    end
  end
end
