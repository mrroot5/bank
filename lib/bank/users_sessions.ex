defmodule Bank.UsersSessions do
  @moduledoc """
  User session related functions
  """

  alias Bank.Repo
  alias Bank.Users.User
  alias Bank.Users.UserNotifier
  alias Bank.Users.UserToken

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  @spec confirm_user(binary()) :: {:ok, Ecto.Schema.t()} | :error
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         # credo:disable-for-next-line
         {:ok, %{user: user}} <- user |> confirm_user_multi() |> Repo.transaction() do
      {:ok, user}
    else
      _ -> :error
    end
  end

  @doc """
  Deletes the signed token with the given context.
  """
  @spec delete_user_session_token(binary()) :: :ok
  def delete_user_session_token(token) do
    token
    |> UserToken.by_token_and_context_query("session")
    |> Repo.delete_all()

    :ok
  end

  @doc ~S"""
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &url(~p"/users/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  @spec deliver_user_confirmation_instructions(Ecto.Schema.t(), fun()) ::
          {:error, :already_confirmed} | UserNotifier.t()
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Generates a session token.
  """
  @spec generate_user_session_token(Ecto.Schema.t()) :: binary()
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  @spec get_user_by_session_token(binary()) :: Ecto.Schema.t() | nil
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  #
  # Private functions
  #

  @spec confirm_user_multi(Ecto.Schema.t()) :: Ecto.Multi.t()
  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, ["confirm"]))
  end
end
