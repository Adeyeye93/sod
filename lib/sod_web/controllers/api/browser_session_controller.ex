defmodule SodWeb.Api.BrowserSessionController do
  use SodWeb, :controller

  alias Sod.Sessions
  alias Sod.Sessions.BrowserSession
  # alias Sod.Accounts

  action_fallback SodWeb.FallbackController

  # Endpoint for chrome extension to validate/create session
  def validate_or_create(conn, params) do
    user = conn.assigns.current_user

    if user do
      case Sessions.validate_or_create_browser_session(user.id, params) do
      {:ok, session} ->
        conn
        |> put_status(:ok)
        |> json(%{
          authenticated: true,
          session_token: session.session_token,
          created_at: session.inserted_at,
          last_activity: session.last_activity,
          is_active: session.is_active,
          user_agent: session.user_agent,
          ip_address: session.ip_address,
          extension_version: session.extension_version,
          browser_fingerprint: session.browser_fingerprint,

        })

      {:error, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to validate or create session"})
    end
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{authenticated: false})
    end


  end

  # Get current session info
  def show(conn, %{"session_token" => session_token}) do
    case Sessions.get_browser_session_by_token(session_token) do
      %BrowserSession{} = session ->
        # Update last activity
        Sessions.update_session_activity(session)

        conn
        |> put_status(:ok)
        |> render("session.json", session: session)

      nil ->
        conn
        |> put_status(:not_found)
        |> render("error.json", error: "Session not found")
    end
  end

  # Update session activity
  def update_activity(conn, %{"session_token" => session_token}) do
    user = conn.assigns.current_user

    case Sessions.get_browser_session_by_token(session_token) do
      %BrowserSession{user_id: user_id} = session when user_id == user.id ->
        case Sessions.update_session_activity(session) do
          {:ok, updated_session} ->
            conn
            |> put_status(:ok)
            |> json(%{
              message: "Session activity updated",
              last_activity: updated_session.last_activity
              })

          {:error, _} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to update session activity"})
        end

      %BrowserSession{} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Session belongs to different user"})

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Session not found"})
    end
  end

  # Get all user sessions
  def index(conn, _params) do
    user = conn.assigns.current_user
    sessions = Sessions.get_user_active_sessions(user.id)

    conn
    |> put_status(:ok)
    |> json(%{sessions: sessions})
  end

  # Deactivate a session
  def deactivate(conn, %{"session_token" => session_token}) do
    user = conn.assigns.current_user

    case Sessions.get_browser_session_by_token(session_token) do
      %BrowserSession{user_id: user_id} = session when user_id == user.id ->
        case Sessions.deactivate_session(session) do
          {:ok, updated_session} ->
            conn
            |> put_status(:ok)
            |> render("session.json", session: updated_session)

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> render("error.json", changeset: changeset)
        end

      %BrowserSession{} ->
        conn
        |> put_status(:forbidden)
        |> render("error.json", error: "Session belongs to different user")

      nil ->
        conn
        |> put_status(:not_found)
        |> render("error.json", error: "Session not found")
    end
  end

  # Deactivate all other sessions except current
  def deactivate_others(conn, %{"session_token" => current_session_token}) do
    user = conn.assigns.current_user

    case Sessions.get_browser_session_by_token(current_session_token) do
      %BrowserSession{user_id: user_id, id: session_id} when user_id == user.id ->
        {count, _} = Sessions.deactivate_other_user_sessions(user.id, session_id)

        conn
        |> put_status(:ok)
        |> json(%{message: "Deactivated #{count} sessions"})

      %BrowserSession{} ->
        conn
        |> put_status(:forbidden)
        |> render("error.json", error: "Session belongs to different user")

      nil ->
        conn
        |> put_status(:not_found)
        |> render("error.json", error: "Session not found")
    end
  end

  def is_authenticated(conn, _) do
    user = conn.assigns.current_user

    if user do
      conn
      |> put_status(:ok)
      |> json(%{authenticated: true})
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{authenticated: false})
    end
  end

def get_auth_data(conn, _) do
  user = conn.assigns.current_user

  if user do
    user_token = get_session(conn, "user_token")

    conn
    |> put_status(:ok)
    |> json(%{
      auth_token: Base.encode64(user_token),
      user_id: user.id,
      expires_at: DateTime.add(DateTime.utc_now(), 60 * 60 * 24 * 7, :second),
      is_authenticated: true,
      last_check: DateTime.utc_now() |> DateTime.to_iso8601(),
      username: user.username
    })
  else
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Not authenticated"})
  end
end
end
