defmodule Vsa.MixProject do
  use Mix.Project

  def project do
    [
      app: :vsa,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:decimal, "~> 2.1"},
      {:req, "~> 0.3.10"},
      {:jason, "~> 1.4"}
    ]
  end
end
