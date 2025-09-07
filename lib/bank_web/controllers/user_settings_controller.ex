defmodule BankWeb.UserSettingsController do
  use BankWeb, :controller

  alias Bank.Users
  alias Bank.UsersSettings
  alias BankWeb.UserAuth
  alias Plug.Conn

  plug :assign_email_and_password_changesets

  @spec edit(Conn.t(), map()) :: Conn.t()
  def edit(conn, _params) do
    render(conn, :edit)
  end

  @spec update(Conn.t(), map()) :: Conn.t()
  def update(conn, %{"action" => "update_email"} = params) do
    %{"current_password" => password, "user" => user_params} = params
    user = conn.assigns.current_user

    case UsersSettings.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        UsersSettings.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        conn
        |> put_flash(
          :info,
          "A link to confirm your email change has been sent to the new address."
        )
        |> redirect(to: ~p"/users/settings")

      {:error, changeset} ->
        render(conn, :edit, email_changeset: changeset)
    end
  end

  @spec update(Conn.t(), map()) :: Conn.t()
  def update(conn, %{"action" => "update_password"} = params) do
    %{"current_password" => password, "user" => user_params} = params
    user = conn.assigns.current_user

    case UsersSettings.update_user_password(user, password, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:user_return_to, ~p"/users/settings")
        |> UserAuth.log_in_user(user)

      {:error, changeset} ->
        render(conn, :edit, password_changeset: changeset)
    end
  end

  @spec confirm_email(Conn.t(), map()) :: Conn.t()
  def confirm_email(conn, %{"token" => token}) do
    case UsersSettings.update_user_email(conn.assigns.current_user, token) do
      :ok ->
        conn
        |> put_flash(:info, "Email changed successfully.")
        |> redirect(to: ~p"/users/settings")

      :error ->
        conn
        |> put_flash(:error, "Email change link is invalid or it has expired.")
        |> redirect(to: ~p"/users/settings")
    end
  end

  @spec assign_email_and_password_changesets(Conn.t(), keyword()) :: Conn.t()
  defp assign_email_and_password_changesets(conn, _opts) do
    user = conn.assigns.current_user

    conn
    |> assign(:email_changeset, UsersSettings.change_user_email(user))
    |> assign(:password_changeset, Users.change_password(user))
  end
end
