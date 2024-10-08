defmodule HikkaBackup.MixProject do
  use Mix.Project

  def project do
    [
      app: :hikka_backup,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: HikkaBackup]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      # mod: {HikkaBackup, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
