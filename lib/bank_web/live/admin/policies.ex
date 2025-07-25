defmodule BankWeb.Headquarters.Policies do
  @moduledoc """
  General purpose authorization module for admin [policies](https://hexdocs.pm/bodyguard/Bodyguard.Policy.html)
  """
  @behaviour Bodyguard.Policy

  use BankWeb, :controller

  action_fallback BankWeb.FallbackController

  def authorize(_, %{roles: roles}, _params), do: :superuser in roles

  def authorize(_action, _user, _params), do: false
end
