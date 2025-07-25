defmodule BankWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use BankWeb, :controller
      use BankWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  @spec static_paths :: [binary()]
  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  @spec router :: Macro.t()
  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  @spec channel :: Macro.t()
  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  @spec controller :: Macro.t()
  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: BankWeb.Layouts]

      use Gettext, backend: BankWeb.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  @spec live_view :: Macro.t()
  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {BankWeb.Layouts, :app}

      unquote(html_helpers())
    end
  end

  @spec live_component :: Macro.t()
  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  @spec html :: Macro.t()
  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  @spec verified_routes :: Macro.t()
  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: BankWeb.Endpoint,
        router: BankWeb.Router,
        statics: BankWeb.static_paths()
    end
  end

  @spec html_helpers :: Macro.t()
  defp html_helpers do
    quote do
      # Translation
      use Gettext, backend: BankWeb.Gettext

      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components
      import BankWeb.CoreComponents

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
