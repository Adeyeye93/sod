defmodule Sod.BackgroundJobs.SessionCleanupWorker do
   @moduledoc """
  Background worker to clean up expired browser sessions.
  Runs periodically to maintain session hygiene.
  """

  use Oban.Worker, queue: :session_cleanup, max_attempts: 3

  alias Sod.Sessions

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"days_threshold" => days_threshold}}) do
    case Sessions.cleanup_expired_sessions(days_threshold) do
      {count, _} when count > 0 ->
        IO.puts("Cleaned up #{count} expired browser sessions")
        :ok

      {0, _} ->
        IO.puts("No expired browser sessions to clean up")
        :ok
    end
  end

  def perform(%Oban.Job{}) do
    # Default to 30 days if no threshold specified
    perform(%Oban.Job{args: %{"days_threshold" => 30}})
  end

  @doc """
  Schedule the cleanup job to run periodically.
  Add this to your application supervision tree or scheduler.
  """
  def schedule_cleanup(days_threshold \\ 30) do
    %{days_threshold: days_threshold}
    |> Sod.BackgroundJobs.SessionCleanupWorker.new(schedule_in: {1, :hour})
    |> Oban.insert()
  end
end
