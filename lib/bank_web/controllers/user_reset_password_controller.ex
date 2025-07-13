defmodule BankWeb.UserResetPasswordController do
  use BankWeb, :controller

  alias Bank.Users
  alias Plug.Conn

  plug :get_user_by_reset_password_token when action in [:edit, :update]

  @spec new(Conn.t(), map()) :: Conn.t()
  def new(conn, _params) do
    render(conn, :new)
  end

  @spec create(Conn.t(), map()) :: Conn.t()
  def create(conn, %{"user" => %{"email" => email}}) do
    if user = Users.get_user_by_email(email) do
      Users.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset_password/#{&1}")
      )
    end

    conn
    |> put_flash(
      :info,
      "If your email is in our system, you will receive instructions to reset your password shortly."
    )
    |> redirect(to: ~p"/")
  end

  @spec edit(Conn.t(), map()) :: Conn.t()
  def edit(conn, _params) do
    render(conn, :edit, changeset: Users.change_user_password(conn.assigns.user))
  end

  # Do not log in the user after reset password to avoid a
  # leaked token giving the user access to the account.
  @spec update(Conn.t(), map()) :: Conn.t()
  def update(conn, %{"user" => user_params}) do
    case Users.reset_user_password(conn.assigns.user, user_params) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Password reset successfully.")
        |> redirect(to: ~p"/users/log_in")

      {:error, changeset} ->
        render(conn, :edit, changeset: changeset)
    end
  end

  @spec get_user_by_reset_password_token(Conn.t(), keyword()) :: Conn.t()
  defp get_user_by_reset_password_token(conn, _opts) do
    %{"token" => token} = conn.params

    if user = Users.get_user_by_reset_password_token(token) do
      conn
      |> assign(:user, user)
      |> assign(:token, token)
    else
      conn
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: ~p"/")
      |> halt()
    end
  end
end
