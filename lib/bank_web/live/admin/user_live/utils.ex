defmodule BankWeb.Headquarters.UserLive.Utils do
  alias Bank.Users.User

  @spec roles_to_string(User.roles()) :: binary()
  def roles_to_string(roles) when is_list(roles) do
    Enum.map_join(roles, ", ", &Atom.to_string/1)
  end
end
