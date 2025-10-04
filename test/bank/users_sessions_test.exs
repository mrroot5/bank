defmodule Bank.UsersSessionsTest do
  use Bank.DataCase, async: true

  alias Bank.Repo
  alias Bank.Users.User
  alias Bank.Users.UserToken
  alias Bank.UsersFixtures
  alias Bank.UsersSessions

  describe "confirm_user/1" do
    setup do
      user = UsersFixtures.fixture()

      token =
        UsersFixtures.extract_user_token(fn url ->
          UsersSessions.deliver_user_confirmation_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "confirms the email with a valid token", %{user: user, token: token} do
      assert {:ok, confirmed_user} = UsersSessions.confirm_user(token)
      assert confirmed_user.confirmed_at
      assert confirmed_user.confirmed_at != user.confirmed_at
      assert Repo.get!(User, user.id).confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm with invalid token", %{user: user} do
      assert UsersSessions.confirm_user("oops") == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert UsersSessions.confirm_user(token) == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "delete_session_token/1" do
    test "deletes the token" do
      user = UsersFixtures.fixture()
      token = UsersSessions.generate_user_session_token(user)
      assert UsersSessions.delete_session_token(token) == :ok
      refute UsersSessions.get_user_by_session_token(token)
    end
  end

  describe "deliver_user_confirmation_instructions/2" do
    setup do
      %{user: UsersFixtures.fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        UsersFixtures.extract_user_token(fn url ->
          UsersSessions.deliver_user_confirmation_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "confirm"
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: UsersFixtures.fixture()}
    end

    test "generates a token", %{user: user} do
      token = UsersSessions.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: UsersFixtures.fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = UsersFixtures.fixture()
      token = UsersSessions.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = UsersSessions.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute UsersSessions.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute UsersSessions.get_user_by_session_token(token)
    end
  end
end
