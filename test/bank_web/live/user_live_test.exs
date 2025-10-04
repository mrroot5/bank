defmodule BankWeb.UserLiveTest do
  use BankWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Bank.Users
  alias BankWeb.ConnCase

  @superuser_role_attrs %{roles: [:superuser]}
  @user_role_attrs %{roles: [:user]}

  setup context, do: ConnCase.register_and_log_in_user(context, @superuser_role_attrs)

  describe "/hq access control" do
    test "superuser can access /hq/users", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/hq/users")
      assert html =~ "Listing Users"
    end

    test "regular user cannot access /hq/users", context do
      %{conn: conn} = ConnCase.register_and_log_in_user(context, @user_role_attrs)

      expected_error = %Bodyguard.NotAuthorizedError{
        message: "You are not allowed to be here",
        status: 403,
        reason: {:error, :unauthorized}
      }

      error =
        assert_raise Bodyguard.NotAuthorizedError, fn ->
          assert {:error, {:redirect, %{to: _to, flash: _flash}}} = live(conn, ~p"/hq/users")
        end

      assert expected_error == error
    end

    test "anonymous user cannot access /hq/users" do
      conn = Phoenix.ConnTest.build_conn()

      assert {:error, {:redirect, %{to: to, flash: flash}}} = live(conn, ~p"/hq/users")
      assert to == "/users/log_in"
      assert flash["error"] =~ "You must log in to access this page."
    end
  end

  describe "Index" do
    test "lists all users", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/hq/users")

      assert html =~ "Listing Users"
    end

    test "loads initial users and paginates on scroll", %{conn: conn} do
      users =
        for i <- 1..30 do
          {:ok, user} =
            Users.register_user(%{
              email: "user#{i}@example.com",
              password: "Test P@ssword-#{i}"
            })

          user
        end

      {:ok, view, html} = live(conn, ~p"/hq/users")
      # Check initial users are rendered
      for user <- Enum.take(users, 10) do
        assert html =~ user.email
      end

      # Simulate infinite scroll event
      view
      |> element("#user-scroll")
      |> render_hook("next-page", %{"page_loading" => true})

      # After next page, more users should be visible
      for user <- Enum.slice(users, 10, 10) do
        assert render(view) =~ user.email
      end
    end

    test "updates user in listing", %{conn: conn, user: user} do
      {:ok, index_live, _html} = live(conn, ~p"/hq/users")

      assert index_live
             |> element("#users-#{user.id} a", "Edit")
             |> render_click() =~ "Edit User"

      assert_patch(index_live, ~p"/hq/users/#{user}/edit")

      assert index_live
             |> form("#user-form", user: @user_role_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/hq/users")

      html = render(index_live)
      assert html =~ "User updated successfully"
    end

    test "deletes user in listing", %{conn: conn, user: user} do
      {:ok, index_live, _html} = live(conn, ~p"/hq/users")

      assert index_live
             |> element("#users-#{user.id} a", "Delete")
             |> render_click()

      refute has_element?(index_live, "#users-#{user.id}")
    end
  end

  describe "Show" do
    test "displays user", %{conn: conn, user: user} do
      {:ok, _show_live, html} = live(conn, ~p"/hq/users/#{user}")

      assert html =~ "Show User"
    end

    test "updates user within modal", %{conn: conn, user: user} do
      {:ok, show_live, _html} = live(conn, ~p"/hq/users/#{user}")

      assert show_live
             |> element("a", "Edit")
             |> render_click() =~ "Edit User"

      assert_patch(show_live, ~p"/hq/users/#{user}/show/edit")

      assert show_live
             |> form("#user-form", user: @user_role_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/hq/users/#{user}")

      html = render(show_live)
      assert html =~ "User updated successfully"
    end
  end
end
