defmodule Bank.Oban.Resolver do
  @moduledoc """
  Oban Web access controls
  """
  @behaviour Oban.Web.Resolver

  @impl Oban.Web.Resolver
  def resolve_user(conn), do: conn.assigns.current_user

  @impl Oban.Web.Resolver
  def resolve_access(user) do
    BankWeb.UserAuth.superuser!(user)

    :all
  rescue
    Bodyguard.NotAuthorizedError ->
      {:forbidden, "/"}
  end
end
