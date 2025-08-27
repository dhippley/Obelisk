defmodule Obelisk.MixProject do
  use Mix.Project

  def project do
    [
      app: :obelisk,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      warnings_as_errors: true,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Obelisk.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
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
      # Phoenix & Web
      {:phoenix, "~> 1.8.0"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:bandit, "~> 1.5"},

      # Database & Storage
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.17"},
      {:pgvector, "~> 0.3"},

      # HTTP & Networking
      {:req, "~> 0.5"},
      {:finch, "~> 0.18"},

      # JSON & Configuration
      {:jason, "~> 1.4"},
      {:yaml_elixir, "~> 2.9"},

      # Machine Learning & Embeddings
      {:nx, "~> 0.7"},
      {:bumblebee, "~> 0.5"},

      # Concurrency & Streaming
      {:broadway, "~> 1.0"},

      # Observability & Telemetry
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:opentelemetry_exporter, "~> 1.7"},

      # Assets & Development
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},

      # Utilities
      {:swoosh, "~> 1.16"},
      {:gettext, "~> 0.26"},
      {:dns_cluster, "~> 0.2.0"},

      # Testing
      {:lazy_html, ">= 0.1.0", only: :test},

      # Code Quality
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.0", only: [:dev, :test], runtime: false}
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
      "assets.build": ["tailwind obelisk", "esbuild obelisk"],
      "assets.deploy": [
        "tailwind obelisk --minify",
        "esbuild obelisk --minify",
        "phx.digest"
      ],
      precommit: ["compile", "deps.unlock --unused", "format", "credo --strict", "test"]
    ]
  end
end
