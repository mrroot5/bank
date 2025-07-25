defmodule BankWeb.FallbackController do
  @moduledoc """
  Handle responses not matched by any other controller.

  This is a Phoenix plug called `action_fallback`, check
  [the docs for more info](https://hexdocs.pm/phoenix/Phoenix.Controller.html#action_fallback/1).
  """
  use BankWeb, :controller

  alias Plug.Conn

  @spec call(Conn.t(), tuple()) :: Conn.t()
  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:forbidden)
    |> put_view(html: BankWeb.ErrorHTML)
    |> render(:"403")
  end
end
