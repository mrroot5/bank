defmodule BankWeb.UserConfirmationController do
  use BankWeb, :controller

  alias Bank.Users
  alias Bank.UsersSessions
  alias Plug.Conn

  @spec new(Conn.t(), map()) :: Conn.t()
  def new(conn, _params) do
    render(conn, :new)
  end

  @spec create(Conn.t(), map()) :: Conn.t()
  def create(conn, %{"user" => %{"email" => email}}) do
    if user = Users.get_user_by_email(email) do
      UsersSessions.deliver_user_confirmation_instructions(
        user,
        &url(~p"/users/confirm/#{&1}")
      )
    end

    conn
    |> put_flash(
      :info,
      "If your email is in our system and it has not been confirmed yet, " <>
        "you will receive an email with instructions shortly."
    )
    |> redirect(to: ~p"/")
  end

  @spec edit(Conn.t(), map()) :: Conn.t()
  def edit(conn, %{"token" => token}) do
    render(conn, :edit, token: token)
  end

  # Do not log in the user after confirmation to avoid a
  # leaked token giving the user access to the account.
  @spec update(Conn.t(), map()) :: Conn.t()
  def update(conn, %{"token" => token}) do
    case UsersSessions.confirm_user(token) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "User confirmed successfully.")
        |> redirect(to: ~p"/")

      :error ->
        # If there is a current user and the account was already confirmed,
        # then odds are that the confirmation link was already visited, either
        # by some automation or by the user themselves, so we redirect without
        # a warning message.
        case conn.assigns do
          %{current_user: %{confirmed_at: confirmed_at}} when not is_nil(confirmed_at) ->
            redirect(conn, to: ~p"/")

          %{} ->
            conn
            |> put_flash(:error, "User confirmation link is invalid or it has expired.")
            |> redirect(to: ~p"/")
        end
    end
  end
end
