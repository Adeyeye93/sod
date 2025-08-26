defmodule Sod.Alerts do
  @moduledoc """
  Handles creation and management of risk-based alerts for users.
  """

  alias Sod.Alarts.RiskAlarts
  alias Sod.Repo

  @doc """
  Creates a high risk visit alert for a user.
  """
  def create_high_risk_visit_alert(user_id, site_id, risk_score, message) do
    %RiskAlarts{}
    |> RiskAlarts.changeset(%{
      user_id: user_id,
      site_id: site_id,
      alert_type: "high_risk_visit",
      risk_score: risk_score,
      message: message,
      violated_preferences: [],
      is_read: false
    })
    |> Repo.insert()
  end

  @doc """
  Creates a preference violation alert for a user.
  """
  def create_preference_violation_alert(user_id, site_id, violated_preferences, message) do
    %RiskAlarts{}
    |> RiskAlarts.changeset(%{
      user_id: user_id,
      site_id: site_id,
      alert_type: "preference_violation",
      violated_preferences: violated_preferences,
      message: message,
      is_read: false
    })
    |> Repo.insert()
  end

  @doc """
  Marks an alert as read.
  """
  def mark_alert_as_read(alert_id) do
    RiskAlarts
    |> Repo.get(alert_id)
    |> RiskAlarts.changeset(%{is_read: true})
    |> Repo.update()
  end

  @doc """
  Records the action taken on an alert.
  """
  def record_alert_action(alert_id, action) when action in ["ignored", "blocked", "proceeded_anyway"] do
    RiskAlarts
    |> Repo.get(alert_id)
    |> RiskAlarts.changeset(%{action_taken: action})
    |> Repo.update()
  end

  # @doc """
  # Gets all unread alerts for a user.
  # """
  # def get_unread_alerts(user_id) do
  #   RiskAlarts
  #   |> where([a], a.user_id == ^user_id and a.is_read == false)
  #   |> Repo.all()
  # end

  # @doc """
  # Gets all alerts for a user within a date range.
  # """
  # def get_alerts_in_range(user_id, start_date, end_date) do
  #   RiskAlarts
  #   |> where([a], a.user_id == ^user_id)
  #   |> where([a], a.inserted_at >= ^start_date and a.inserted_at <= ^end_date)
  #   |> Repo.all()
  # end
end
