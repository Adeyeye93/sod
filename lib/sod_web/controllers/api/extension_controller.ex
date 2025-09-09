defmodule SodWeb.API.ExtensionController do
  use SodWeb, :controller

  alias Sod.{Sites, Alerts, Preferences, RiskAnalyzer}
  alias Sod.Repo
  alias Sod.Sessions.BrowserSession

  @doc """
  Creates or gets a site by domain. Used when extension visits a new site.
  """
 def get_or_create_site(conn, %{"domain" => domain}) do
  with {:ok, site} <- Sites.get_or_create_site_by_domain(domain) do
    site =
      site
      |> Repo.preload([:site_risk_analysis, :site_visits, :tos_versions])
      |> Map.from_struct()
      |> Map.drop([:__meta__, :__struct__])

    json(conn, %{site: site})
  end
end

def site_available(conn, %{"domain" => domain}) do
  case Sites.get_site_by_domain(domain) do
    {:ok, site} ->
      site =
        site
        |> Repo.preload([:site_risk_analysis, :site_visits, :tos_versions])
        |> Map.from_struct()
        |> Map.drop([:__meta__, :__struct__])
      json(conn, site)
    _ ->
      json(conn, %{error: "Site not found"})
  end
end


  @doc """
  Analyzes TOS content for a specific site.
  Content can be provided directly or will be scraped if domain is provided instead.
  Returns the analysis with personalized recommendations if session token is provided.
  """
  def analyze_site_content(conn, %{"content" => content, "content_type" => content_type, "site_id" => site_id} = _params) do
    session_token = get_req_header(conn, "x-session-token")

    # Get user preferences if session token is provided
    analysis_result = case get_user_from_session(session_token) do
      {:ok, user} ->
        with {:ok, preferences} <- Preferences.get_or_create_user_preference(user),
             {:ok, source, analysis} <- RiskAnalyzer.analyze_for_user(content, content_type, site_id, preferences) do
          {:ok, :personalized, source, analysis}
        end

      _ ->
        # Fallback to basic analysis without user preferences
        with {:ok, analysis} <- RiskAnalyzer.analyze_tos_content(content, content_type, site_id) do
          {:ok, :basic, "cache", analysis}
        end
    end

    case analysis_result do
      {:ok, type, source, analysis} ->
        conn
        |> put_status(:ok)
        |> json(%{type: type, source: source, analysis: analysis})

      {:error, _reason} = error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("error.json", error: error)
    end
  end

  @doc """
  Gets or creates user preferences using session token.
  """
  def get_user_preferences(conn, _params) do
    with [session_token] <- get_req_header(conn, "x-session-token"),
         {:ok, user} <- get_user_from_session(session_token),
         {:ok, preferences} <- Preferences.get_or_create_user_preference(user) do
      conn
      |> put_status(:ok)

      json(conn, preferences)
    else
      _ ->
        conn
        |> put_status(:unauthorized)

        json(conn, %{error: "Invalid session token"})
        # |> render("error.json", error: "Invalid session token")
    end
  end

  @doc """
  Updates user preferences using session token.
  """
  def update_preferences(conn, %{"preferences" => preferences_params}) do
    with [session_token] <- get_req_header(conn, "x-session-token"),
         {:ok, user} <- get_user_from_session(session_token),
         {:ok, current_preferences} <- Preferences.get_or_create_user_preference(user),
         {:ok, updated_preferences} <- Preferences.update_user_preference(current_preferences, preferences_params) do
      conn
      |> put_status(:ok)
      |> render("preferences.json", preferences: updated_preferences)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> render("error.json", error: "Invalid session token")
    end
  end

  @doc """
  Gets unread alerts for the user using session token.
  """
  def get_unread_alerts(conn, _params) do
    with [session_token] <- get_req_header(conn, "x-session-token"),
         {:ok, user} <- get_user_from_session(session_token) do
      alerts = Alerts.get_unread_alerts(user.id)

      conn
      |> put_status(:ok)
      |> render("alerts.json", alerts: alerts)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> render("error.json", error: "Invalid session token")
    end
  end

  @doc """
  Marks an alert as read.
  """
  def mark_alert_read(conn, %{"alert_id" => alert_id}) do
    with [session_token] <- get_req_header(conn, "x-session-token"),
         {:ok, _user} <- get_user_from_session(session_token),
         {:ok, _alert} <- Alerts.mark_alert_as_read(alert_id) do
      conn
      |> put_status(:ok)
      |> json(%{success: true})
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> render("error.json", error: "Invalid session token")
    end
  end

  @doc """
  Records user's action on an alert (blocked, proceeded, etc.).
  """
  def record_alert_action(conn, %{"alert_id" => alert_id, "action" => action})
  when action in ["ignored", "blocked", "proceeded_anyway"] do
    with [session_token] <- get_req_header(conn, "x-session-token"),
         {:ok, _user} <- get_user_from_session(session_token),
         {:ok, _alert} <- Alerts.record_alert_action(alert_id, action) do
      conn
      |> put_status(:ok)
      |> json(%{success: true})
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> render("error.json", error: "Invalid session token")
    end
  end

  # Private helper functions

  defp get_user_from_session([session_token]) do
    case Repo.get_by(BrowserSession, session_token: session_token, is_active: true) do
      %BrowserSession{user: user} = session ->
        # Update last activity
        session
        |> BrowserSession.changeset(%{last_activity: NaiveDateTime.utc_now()})
        |> Repo.update()

        {:ok, user}

      nil ->
        {:error, :invalid_session}
    end
  end
  defp get_user_from_session(_), do: {:error, :invalid_session}
end
