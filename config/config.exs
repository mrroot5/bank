# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :bank,
  default_currency: "EUR",
  ecto_repos: [Bank.Repo],
  env: config_env(),
  generators: [timestamp_type: :utc_datetime_usec]

# Configures the endpoint
config :bank, BankWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: BankWeb.ErrorHTML, json: BankWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Bank.PubSub,
  live_view: [signing_salt: "xK1fj3bx"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :bank, Bank.Mailer, adapter: Swoosh.Adapters.Local

config :bank, Bank.Cldr,
  # a single locale, for fast compilation in dev / test
  locales: ["en-*", "es-*"]

config :bank, Oban,
  engine: Oban.Engines.Basic,
  # queues name: limit is a local concurrency limit by node
  queues: [default: 1, transactions: 2],
  notifier: Oban.Notifiers.PG,
  repo: Bank.Repo

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  bank: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :ex_cldr,
  default_locale: "en",
  default_backend: Bank.Cldr

config :ex_money,
  auto_start_exchange_rate_service: false,
  # each hour
  exchange_rates_retrieve_every: 3_600_000

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  bank: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
