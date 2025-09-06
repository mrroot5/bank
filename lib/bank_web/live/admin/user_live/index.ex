defmodule BankWeb.Headquarters.UserLive.Index do
  use BankWeb, :live_view

  alias Bank.Users
  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket

  @per_page 10

  @impl LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:end_of_timeline?, false)
      |> assign(:last_id, nil)

    if connected?(socket) do
      {:ok, paginate_users(socket, nil)}
    else
      {:ok, stream(socket, :users, [])}
    end
  end

  defp paginate_users(socket, after_id) do
    users =
      if after_id do
        Users.list_paginated(after_id: after_id, limit: @per_page)
      else
        Users.list_paginated(limit: @per_page)
      end

    end_of_timeline = length(users) < @per_page

    last_id =
      case List.last(users) do
        nil -> socket.assigns[:last_id]
        user -> user.id
      end

    socket
    |> assign(:end_of_timeline?, end_of_timeline)
    |> assign(:last_id, last_id)
    |> stream(:users, users, at: -1)
  end

  @impl LiveView
  def handle_event("next-page", _, socket) do
    {:noreply, paginate_users(socket, socket.assigns.last_id)}
  end

  # prev-page not implemented for after_id keyset (forward only)
  @impl LiveView
  def handle_event("prev-page", _, socket) do
    {:noreply, socket}
  end

  @impl LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    user = Users.get_user!(id)
    {:ok, _} = Users.delete_user(user)

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
    |> assign(:user, Users.get_user!(id))
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Users")
    |> assign(:user, nil)
  end
end
