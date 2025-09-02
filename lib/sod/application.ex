defmodule Sod.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SodWeb.Telemetry,
      Sod.Repo,
      {DNSCluster, query: Application.get_env(:sod, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Sod.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Sod.Finch},
      # Start a worker by calling: Sod.Worker.start_link(arg)
      # {Sod.Worker, arg},
      # Start to serve requests, typically the last entry
      SodWeb.Endpoint,
      Sod.BackgroundJobs.AiAnalyzer
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Sod.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SodWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
