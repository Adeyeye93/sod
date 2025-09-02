defmodule SodWeb.API.RiskController do
  use SodWeb, :controller

  alias Sod.{RiskAnalyzer, Alerts, Analytics}
  # alias Sod.Preference.UserPreference

  action_fallback SodWeb.FallbackController

  @doc """
  Analyzes Terms of Service content for a specific site.
  """
  def analyze_tos(conn, %{"content" => content, "content_type" => content_type, "site_id" => site_id} = params) do
    with {:ok, _analysis} <- RiskAnalyzer.analyze_tos_content(content, content_type, site_id, Map.get(params, "options", [])) do
      conn
      |> put_status(:ok)
    end
  end

  @doc """
  Analyzes Terms of Service content for a specific user, considering their preferences.
  """
  def analyze_for_user(conn, %{"content" => content, "content_type" => content_type, "site_id" => site_id}) do
    user = conn.assigns.current_user

    with {:ok, user_preferences} <- ensure_user_preferences(user),
         {:ok, source, analysis} <- RiskAnalyzer.analyze_for_user(content, content_type, site_id, user_preferences) do
      conn
      |> put_status(:ok)
      |> render("personalized_analysis.json", analysis: analysis, source: source)
    end
  end

  @doc """
  Gets all alerts for the current user with pagination.
  """
  def list_alerts(conn, params) do
    user = conn.assigns.current_user
    page = Map.get(params, "page", 1)
    per_page = Map.get(params, "per_page", 20)

    alerts = Alerts.get_user_alerts(user.id, page, per_page)

    conn
    |> put_status(:ok)
    |> render("alerts.json", alerts: alerts)
  end

  @doc """
  Gets unread alerts for the current user.
  """
  def unread_alerts(conn, _params) do
    user = conn.assigns.current_user
    alerts = Alerts.get_unread_alerts(user.id)

    conn
    |> put_status(:ok)
    |> render("alerts.json", alerts: alerts)
  end

  @doc """
  Marks an alert as read.
  """
  def mark_as_read(conn, %{"alert_id" => alert_id}) do
    with {:ok, alert} <- Alerts.mark_alert_as_read(alert_id) do
      conn
      |> put_status(:ok)
      |> render("alert.json", alert: alert)
    end
  end

  @doc """
  Records an action taken on an alert (ignored/blocked/proceeded_anyway).
  """
  # def record_action(conn, %{"alert_id" => alert_id, "action" => action})
  # when action in ["ignored", "blocked", "proceeded_anyway"] do
  #   with {:ok, alert} <- Alarts.create_risk_alert(alert_id, action) do
  #     conn
  #     |> put_status(:ok)
  #     |> render("alert.json", alert: alert)
  #   end
  # end

  # @doc """
  # Gets risk analysis summary for the current user.
  # """
  def user_risk_summary(conn, _params) do
    user = conn.assigns.current_user

    # Gather various risk statistics
    visit_stats = Analytics.get_user_visit_statistics(user.id)
    alert_stats = Alerts.get_user_alert_statistics(user.id)
    high_risk_sites = Analytics.get_user_high_risk_sites(user.id)

    conn
    |> put_status(:ok)
    |> render("risk_summary.json", %{
      visit_statistics: visit_stats,
      alert_statistics: alert_stats,
      high_risk_sites: high_risk_sites
    })
  end

  # Private helper functions

  defp ensure_user_preferences(user) do
    case Sod.Preferences.get_or_create_user_preference(user) do
      {:ok, preferences} -> {:ok, preferences}
      {:error, _changeset} -> {:error, :preferences_not_found}
    end
  end
end
