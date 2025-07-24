defmodule BankWeb.Admin.UserLive.Utils do
  alias Bank.Users.User

  @spec roles_to_string(User.roles()) :: [binary()]
  def roles_to_string(roles) when is_list(roles) do
    roles
    |> Enum.map(&Atom.to_string/1)
    |> Enum.join(", ")
  end
end
