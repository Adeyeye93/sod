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
end
