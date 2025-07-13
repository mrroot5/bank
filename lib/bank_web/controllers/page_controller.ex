defmodule BankWeb.PageController do
  use BankWeb, :controller

  @spec home(Plug.Conn.t(), map()) :: Phoenix.HTML.Safe.t()
  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end
end
