defmodule Bank.UsersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Bank.Users` context.
  """

  @spec unique_user_email :: String.t()
  def unique_user_email, do: "user#{System.unique_integer()}@example.com"

  @spec valid_user_password :: String.t()
  def valid_user_password, do: "Hello w0rld!"

  @spec valid_user_attributes(map()) :: map()
  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  @spec fixture(map()) :: Ecto.Schema.t()
  def fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Bank.Users.register_user()

    user
  end

  @spec extract_user_token(fun()) :: binary()
  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
