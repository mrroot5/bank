defmodule BankWeb.UserRegistrationController do
  use BankWeb, :controller

  alias Bank.Users
  alias Bank.Users.User
  alias Bank.UsersSessions
  alias BankWeb.UserAuth
  alias Plug.Conn

  @spec new(Conn.t(), map()) :: Conn.t()
  def new(conn, _params) do
    changeset = Users.change_user_registration(%User{})
    render(conn, :new, changeset: changeset)
  end

  @spec create(Conn.t(), map()) :: Conn.t()
  def create(conn, %{"user" => user_params}) do
    case Users.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          UsersSessions.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        conn
        |> put_flash(:info, "User created successfully.")
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end
end
