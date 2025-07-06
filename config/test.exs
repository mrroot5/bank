import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :argon2_elixir, t_cost: 1, m_cost: 8

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :bank, Bank.Repo,
  username: "postgres_test",
  password: "postgres_test",
  hostname: System.get_env("PG_HOST") || "postgres_test",
  database: "bank_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :bank, Bank.Cldr,
  # a single locale, for fast compilation in dev / test
  locales: ["en", "es"]

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :bank, BankWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "xI7gLoWXepp5offcIThInTRJm4x4xTgkKxC+ucf9rm94GX5E7Jkqy6p9JZ6RHhX8",
  server: false

# In test we don't send emails
config :bank, Bank.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
