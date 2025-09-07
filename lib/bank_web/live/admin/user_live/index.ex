defmodule BankWeb.Headquarters.UserLive.Index do
  use BankWeb, :live_view

  alias Bank.Users
  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket

  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :users, Users.list())}
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
end
