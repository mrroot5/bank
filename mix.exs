defmodule Bank.MixProject do
  use Mix.Project

  def project do
    [
      app: :bank,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(get_mix_env()),
      start_permanent: get_mix_env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: dialyzer()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Bank.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:argon2_elixir, "~> 3.0"},
      {:bandit, "~> 1.5"},
      {:bodyguard, "~> 2.4"},
      {:credo, "~> 1.7", only: :dev, runtime: false},
      {:decimal, "~> 2.0"},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:dns_cluster, "~> 0.2.0"},
      {:ecto_sql, "~> 3.10"},
      {:esbuild, "~> 0.8", runtime: get_mix_env() == :dev},
      {:excellent_migrations, "~> 0.1", only: :dev, runtime: false},
      {:ex_money, "~> 5.0"},
      {:finch, "~> 0.13"},
      {:floki, ">= 0.30.0", only: :test},
      {:gettext, "~> 0.26"},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:jason, "~> 1.2"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix, "~> 1.7.21"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:postgrex, ">= 0.0.0"},
      {:recode, "~> 0.7", only: :dev, runtime: false},
      {:tailwind, "~> 0.3.1", runtime: get_mix_env() == :dev},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:swoosh, "~> 1.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind bank", "esbuild bank"],
      "assets.deploy": [
        "tailwind bank --minify",
        "esbuild bank --minify",
        "phx.digest"
      ]
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix],
      # Prevent xmerl warnings that would be added on a future otp version > 28
      plt_ignore_apps: [:xmerl],
      ignore_warnings: ".dialyzer_ignore.exs"
    ]
  end

  # Get mix env from system environment or mix library.
  @spec get_mix_env :: atom()
  defp get_mix_env, do: get_mix_env(System.get_env("MIX_ENV"))

  # TODO Esto deberia fallar y pedir que se agregue el segundo tipo de spec ya que este tiene un arity de 1 no de 0
  defp get_mix_env(nil), do: Mix.env()

  defp get_mix_env(mix_env) when is_binary(mix_env), do: String.to_atom(mix_env)
end
