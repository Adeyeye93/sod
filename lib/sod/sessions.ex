defmodule Sod.Sessions do
  @moduledoc """
  The Sessions context for managing browser sessions and authentication tokens.
  """

  import Ecto.Query, warn: false
  alias Sod.Repo
  alias Sod.Sessions.BrowserSession
  # alias Sod.Accounts.User

  @doc """
  Creates a browser session.
  """
  def create_browser_session(attrs \\ %{}) do
    %BrowserSession{}
    |> BrowserSession.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a browser session by session token.
  """
  def get_browser_session_by_token(token) do
    Repo.get_by(BrowserSession, session_token: token)
    |> Repo.preload(:user)
  end

  @doc """
  Gets active browser sessions for a user.
  """
  def get_user_active_sessions(user_id) do
    from(bs in BrowserSession,
      where: bs.user_id == ^user_id and bs.is_active == true,
      order_by: [desc: bs.last_activity]
    )
    |> Repo.all()
  end

  @doc """
  Updates browser session activity.
  """
  def update_session_activity(%BrowserSession{} = session) do
    session
    |> BrowserSession.changeset(%{last_activity: NaiveDateTime.utc_now()})
    |> Repo.update()
  end

  @doc """
  Deactivates a browser session.
  """
  def deactivate_session(%BrowserSession{} = session) do
    session
    |> BrowserSession.changeset(%{is_active: false})
    |> Repo.update()
  end

  @doc """
  Deactivates all sessions for a user except the current one.
  """
  def deactivate_other_user_sessions(user_id, current_session_id) do
    from(bs in BrowserSession,
      where: bs.user_id == ^user_id and bs.id != ^current_session_id
    )
    |> Repo.update_all(set: [is_active: false])
  end

  @doc """
  Validates or creates a browser session for chrome extension.
  This function handles the logic for creating/updating sessions when a user logs in.
  """
  def validate_or_create_browser_session(user_id, params) do
    session_token = params["session_token"]
    browser_fingerprint = params["browser_fingerprint"]

    # Try to find existing session by token
    case get_browser_session_by_token(session_token) do
      %BrowserSession{user_id: ^user_id, is_active: true} = session ->
        # Update existing session with new data
        update_session_data(session, params)

      %BrowserSession{user_id: ^user_id, is_active: false} = session ->
        # Reactivate deactivated session
        reactivate_session(session, params)

      %BrowserSession{user_id: _different_user_id} ->
        # Session belongs to different user, create new one
        create_new_session(user_id, params)

      nil ->
        # Check if user has existing session with same fingerprint
        case get_session_by_fingerprint(user_id, browser_fingerprint) do
          %BrowserSession{} = existing_session ->
            # Update existing session with new token
            update_session_token(existing_session, params)

          nil ->
            # Create completely new session
            create_new_session(user_id, params)
        end
    end
  end

  @doc """
  Gets session by user ID and browser fingerprint.
  """
  def get_session_by_fingerprint(user_id, fingerprint) do
    from(bs in BrowserSession,
      where: bs.user_id == ^user_id and
             bs.browser_fingerprint == ^fingerprint and
             bs.is_active == true,
      order_by: [desc: bs.last_activity],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Creates or updates session on user login.
  This should be called from your authentication controller.
  """
  def handle_user_login(user_id, session_params \\ %{}) do
    # Deactivate any existing sessions if user wants single session
    # Uncomment the line below if you want to enforce single active session per user
    # deactivate_all_user_sessions(user_id)

    # Create new session for the login
    session_attrs = %{
      user_id: user_id,
      session_token: generate_session_token(),
      browser_fingerprint: session_params["browser_fingerprint"] || generate_browser_fingerprint(),
      user_agent: session_params["user_agent"],
      ip_address: session_params["ip_address"],
      extension_version: session_params["extension_version"],
      is_active: true,
      last_activity: NaiveDateTime.utc_now()
    }

    create_browser_session(session_attrs)
  end

  @doc """
  Deactivates all sessions for a user.
  """
  def deactivate_all_user_sessions(user_id) do
    from(bs in BrowserSession, where: bs.user_id == ^user_id)
    |> Repo.update_all(set: [is_active: false])
  end

  @doc """
  Cleans up expired sessions (inactive for more than X days).
  """
  def cleanup_expired_sessions(days_threshold \\ 30) do
    expiry_date = NaiveDateTime.utc_now() |> NaiveDateTime.add(-days_threshold, :day)

    from(bs in BrowserSession,
      where: bs.last_activity < ^expiry_date or is_nil(bs.last_activity)
    )
    |> Repo.update_all(set: [is_active: false])
  end

  # Private helper functions

  defp update_session_data(%BrowserSession{} = session, params) do
    attrs = %{
      user_agent: params["user_agent"] || session.user_agent,
      ip_address: params["ip_address"] || session.ip_address,
      extension_version: params["extension_version"] || session.extension_version,
      last_activity: NaiveDateTime.utc_now()
    }

    session
    |> BrowserSession.changeset(attrs)
    |> Repo.update()
  end

  defp reactivate_session(%BrowserSession{} = session, params) do
    attrs = %{
      is_active: true,
      user_agent: params["user_agent"] || session.user_agent,
      ip_address: params["ip_address"] || session.ip_address,
      extension_version: params["extension_version"] || session.extension_version,
      last_activity: NaiveDateTime.utc_now()
    }

    session
    |> BrowserSession.changeset(attrs)
    |> Repo.update()
  end

  defp update_session_token(%BrowserSession{} = session, params) do
    attrs = %{
      session_token: params["session_token"],
      user_agent: params["user_agent"] || session.user_agent,
      ip_address: params["ip_address"] || session.ip_address,
      extension_version: params["extension_version"] || session.extension_version,
      is_active: true,
      last_activity: NaiveDateTime.utc_now()
    }

    session
    |> BrowserSession.changeset(attrs)
    |> Repo.update()
  end

  defp create_new_session(user_id, params) do
    attrs = %{
      user_id: user_id,
      session_token: params["session_token"],
      browser_fingerprint: params["browser_fingerprint"],
      user_agent: params["user_agent"],
      ip_address: params["ip_address"],
      extension_version: params["extension_version"],
      is_active: true,
      last_activity: NaiveDateTime.utc_now()
    }

    create_browser_session(attrs)
  end

  defp generate_session_token do
    :crypto.strong_rand_bytes(32) |> Base.encode64()
  end

  defp generate_browser_fingerprint do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end
end
