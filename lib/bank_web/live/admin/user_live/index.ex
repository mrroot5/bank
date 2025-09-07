defmodule BankWeb.Headquarters.UserLive.Index do
  use BankWeb, :live_view

  alias Bank.Users
  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket

  @per_page 20

  @impl LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:end_of_timeline?, false)
      |> assign(:last_inserted_at, nil)

    if connected?(socket) do
      {:ok, paginate_users(socket)}
    else
      {:ok, stream(socket, :users, [])}
    end
  end

  @impl LiveView
  def handle_event("next-page", _, socket) do
    {:noreply, paginate_users(socket, socket.assigns.last_inserted_at)}
  end

  @impl LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    user = Users.get!(id)
    {:ok, _} = Users.delete(user)

    {:noreply, stream_delete(socket, :users, user)}
  end

  @impl LiveView
  def handle_info({BankWeb.Headquarters.UserLive.FormComponent, {:saved, user}}, socket) do
    {:noreply, stream_insert(socket, :users, user)}
  end

  @impl LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @spec apply_action(Socket.t(), atom(), map()) :: Socket.t()
  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit User")
    |> assign(:user, Users.get!(id))
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Users")
    |> assign(:user, nil)
  end

  @spec paginate_users(Socket.t(), NaiveDateTime.t() | false) :: Socket.t()
  defp paginate_users(socket, after_inserted_at \\ false) do
    users =
      if after_inserted_at do
        Users.list_paginated(after_inserted_at: after_inserted_at, limit: @per_page)
      else
        Users.list_paginated(limit: @per_page)
      end

    end_of_timeline = length(users) < @per_page

    last_inserted_at =
      case List.last(users) do
        nil -> socket.assigns[:last_inserted_at]
        user -> user.inserted_at
      end

    socket
    |> assign(:end_of_timeline?, end_of_timeline)
    |> assign(:last_inserted_at, last_inserted_at)
    |> stream(:users, users, at: -1)
  end
end
