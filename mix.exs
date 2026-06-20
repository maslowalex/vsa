defmodule Vsa.MixProject do
  use Mix.Project

  @version "0.5.0"
  @source_url "https://gitlab.com/maslo.rails/vsa"

  def project do
    [
      app: :vsa,
      version: @version,
      author: "Olexandr Maslo",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "VSA",
      description:
        "Volume Spread Analysis engine that annotates OHLCV bars with Tom Williams / " <>
          "Tradeguider signs of strength and weakness.",
      source_url: @source_url,
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:decimal, "~> 2.1"},
      {:req, "~> 0.5.8", optional: true},
      {:stream_data, "~> 1.0", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v#{@version}",
      groups_for_modules: [
        Core: [VSA, VSA.Context],
        "Pattern detection": [Vsa.Tag, VSA.Setup],
        "Data structures": [VSA.Bar, VSA.TagEvent, VSA.Level],
        Configuration: [VSA.Thresholds]
      ]
    ]
  end
end
