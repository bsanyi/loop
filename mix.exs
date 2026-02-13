defmodule Loop.MixProject do
  use Mix.Project

  def project do
    [
      app: :loop,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: "Imperative style loops - functional performance",
      package: package(),
      deps: deps(),
      test_coverage: [
        summary: [threshold: 64],
        ignore_modules: []
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

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:credo, "~> 1.0", only: :dev, runtime: false}
    ]
  end
end
