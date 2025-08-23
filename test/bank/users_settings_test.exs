defmodule Bank.UsersSettingsTest do
  use Bank.DataCase, async: true

  alias Bank.UsersSettings
  alias Bank.Users
  alias Bank.Users.User
  alias Bank.Users.UserToken
  alias Bank.UsersFixtures
  alias Bank.UsersSessions
  alias Bank.Repo

  @new_valid_password "New valid passw0rd!"

  describe "apply_user_email/3" do
    setup do
      %{user: UsersFixtures.fixture()}
    end

    test "requires email to change", %{user: user} do
      {:error, changeset} =
        UsersSettings.apply_user_email(user, UsersFixtures.valid_user_password(), %{})

      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{user: user} do
      {:error, changeset} =
        UsersSettings.apply_user_email(user, UsersFixtures.valid_user_password(), %{
          email: "not valid"
        })

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        UsersSettings.apply_user_email(user, UsersFixtures.valid_user_password(), %{
          email: too_long
        })

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{user: user} do
      %{email: email} = UsersFixtures.fixture()
      password = UsersFixtures.valid_user_password()

      {:error, changeset} = UsersSettings.apply_user_email(user, password, %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        UsersSettings.apply_user_email(user, "invalid", %{
          email: UsersFixtures.unique_user_email()
        })

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{user: user} do
      email = UsersFixtures.unique_user_email()

      {:ok, user} =
        UsersSettings.apply_user_email(user, UsersFixtures.valid_user_password(), %{email: email})

      assert user.email == email
      assert Users.get_user!(user.id).email != email
    end
  end

  describe "change_user_email/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = UsersSettings.change_user_email(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "change_user_password/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Users.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Users.change_user_password(%User{}, %{
          "password" => @new_valid_password
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == @new_valid_password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    setup do
      %{user: UsersFixtures.fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        UsersFixtures.extract_user_token(fn url ->
          UsersSettings.deliver_user_update_email_instructions(user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "update_user_email/2" do
    setup do
      user = UsersFixtures.fixture()
      email = UsersFixtures.unique_user_email()

      token =
        UsersFixtures.extract_user_token(fn url ->
          UsersSettings.deliver_user_update_email_instructions(
            %{user | email: email},
            user.email,
            url
          )
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert UsersSettings.update_user_email(user, token) == :ok
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      assert changed_user.confirmed_at
      assert changed_user.confirmed_at != user.confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert UsersSettings.update_user_email(user, "oops") == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert UsersSettings.update_user_email(%{user | email: "current@example.com"}, token) ==
               :error

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert UsersSettings.update_user_email(user, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "update_user_password/3" do
    setup do
      %{user: UsersFixtures.fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        UsersSettings.update_user_password(user, UsersFixtures.valid_user_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: [
                 "at least one digit or punctuation character",
                 "at least one upper case character",
                 "should be at least 12 character(s)"
               ],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        UsersSettings.update_user_password(user, UsersFixtures.valid_user_password(), %{
          password: too_long
        })

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        UsersSettings.update_user_password(user, "invalid", %{
          password: UsersFixtures.valid_user_password()
        })

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{user: user} do
      {:ok, user} =
        UsersSettings.update_user_password(user, UsersFixtures.valid_user_password(), %{
          password: @new_valid_password
        })

      assert is_nil(user.password)
      assert Users.get_user_by_email_and_password(user.email, @new_valid_password)
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = UsersSessions.generate_user_session_token(user)

      {:ok, _} =
        UsersSettings.update_user_password(user, UsersFixtures.valid_user_password(), %{
          password: @new_valid_password
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end
end
