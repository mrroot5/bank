defmodule Bank.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      BankWeb.Telemetry,
      Bank.Repo,
      {DNSCluster, query: Application.get_env(:bank, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Bank.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Bank.Finch},
      # Start a worker by calling: Bank.Worker.start_link(arg)
      # {Bank.Worker, arg},
      # Start to serve requests, typically the last entry
      BankWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Bank.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    BankWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
