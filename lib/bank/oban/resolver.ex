defmodule Bank.Oban.Resolver do
  @behaviour Oban.Web.Resolver

  @impl true
  def resolve_user(conn), do: conn.assigns.current_user

  @impl true
  def resolve_access(user), do: BankWeb.UserAuth.superuser?(user)
end
