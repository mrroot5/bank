defmodule BankWeb.UserSessionController do
  use BankWeb, :controller

  alias Bank.Users
  alias BankWeb.UserAuth
  alias Plug.Conn

  # @spec create(Conn.t(), map()) :: Conn.t()
  # def create(conn, %{"_action" => "registered"} = params) do
  #   create(conn, params, "Account created successfully!")
  # end

  # def create(conn, %{"_action" => "password_updated"} = params) do
  #   conn
  #   |> put_session(:user_return_to, ~p"/users/settings")
  #   |> create(params, "Password updated successfully!")
  # end

  # def create(conn, params) do
  #   create(conn, params, "Welcome back!")
  # end

  # @spec delete(Conn.t(), map()) :: Conn.t()
  # def delete(conn, _params) do
  #   conn
  #   |> put_flash(:info, "Logged out successfully.")
  #   |> UserAuth.log_out_user()
  # end

  # @spec create(Conn.t(), map(), binary()) :: Conn.t()
  # defp create(conn, %{"user" => user_params}, info) do
  #   %{"email" => email, "password" => password} = user_params

  #   if user = Users.get_user_by_email_and_password(email, password) do
  #     conn
  #     |> put_flash(:info, info)
  #     |> UserAuth.log_in_user(user, user_params)
  #   else
  #     # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
  #     conn
  #     |> put_flash(:error, "Invalid email or password")
  #     |> put_flash(:email, String.slice(email, 0, 160))
  #     |> redirect(to: ~p"/users/log_in")
  #   end
  # end
  @spec new(Conn.t(), map()) :: Conn.t()
  def new(conn, _params) do
    render(conn, :new, error_message: nil)
  end

  @spec create(Conn.t(), map()) :: Conn.t()
  def create(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params

    if user = Users.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> UserAuth.log_in_user(user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      render(conn, :new, error_message: "Invalid email or password")
    end
  end

  @spec delete(Conn.t(), map()) :: Conn.t()
  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
