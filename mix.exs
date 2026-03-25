defmodule Loop.MixProject do
  use Mix.Project

  def project do
    [
      app: :loop,
      version: "0.1.2",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: "Imperative style loops - functional performance",
      package: package(),
      deps: deps(),
      docs: docs(),
      aliases: aliases(),
      test_coverage: [
        summary: [threshold: 64],
        ignore_modules: []
      ],
      test_pattern: "*_test.exs"
    ]
  end

  def cli do
    [
      preferred_envs: [
        precommit: :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      name: :loop,
      files: ~w(lib mix.exs README.md LICENSE),
      licenses: ["MIT"],
      maintainers: ["Sandor Bedo"],
      links: %{"GitHub" => "https://github.com/bsanyi/loop"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: "https://github.com/bsanyi/loop"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      precommit: [
        "compile --warnings-as-errors",
        "format",
        "cmd echo \v=== mix test ===",
        "test",
        "cmd echo \v=== mix credo ===",
        "cmd mix credo list",
        "cmd echo \v=== mix dialyzer ===",
        "cmd mix dialyzer --quiet-with-result"
      ]
    ]
  end
end
