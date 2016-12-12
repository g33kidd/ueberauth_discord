defmodule Ueberauth.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [app: :ueberauth_discord,
     version: @version,
     name: "Ueberauth Discord",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :ueberauth, :oauth2]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:ueberauth, "~> 0.4"},
     {:oauth2, "0.6.0"},

     # docs dependencies
     {:earmark, "~> 0.2", only: :dev},
     {:ex_doc, ">= 0.0.0", only: :dev}]
  end
end
