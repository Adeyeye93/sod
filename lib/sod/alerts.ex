defmodule Sod.Alerts do
 @moduledoc """
  The Alerts context for managing risk alerts and notifications.
  """

  import Ecto.Query, warn: false
  alias Sod.Repo
  alias Sod.Alarts.RiskAlarts, as: RiskAlart
  alias Sod.Accounts.User
  alias Sod.Sites.Site

  @doc """
  Creates a risk alert.
  """
  def create_risk_alert(attrs \\ %{}) do
    %RiskAlart{}
    |> RiskAlart.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets unread risk alerts for a user.
  """
  def get_unread_alerts(user_id) do
    from(ra in RiskAlart,
      where: ra.user_id == ^user_id and ra.is_read == false,
      order_by: [desc: ra.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets all risk alerts for a user with pagination.
  """
  def get_user_alerts(user_id, page \\ 1, per_page \\ 20) do
    offset = (page - 1) * per_page

    from(ra in RiskAlart,
      join: s in assoc(ra, :site),
      where: ra.user_id == ^user_id,
      order_by: [desc: ra.inserted_at],
      offset: ^offset,
      limit: ^per_page,
      preload: [site: s]
    )
    |> Repo.all()
  end

  @doc """
  Marks an alert as read.
  """
  def mark_alert_as_read(%RiskAlart{} = alert) do
    alert
    |> RiskAlart.changeset(%{is_read: true})
    |> Repo.update()
  end

  @doc """
  Marks multiple alerts as read.
  """
  def mark_alerts_as_read(alert_ids) when is_list(alert_ids) do
    from(ra in RiskAlart, where: ra.id in ^alert_ids)
    |> Repo.update_all(set: [is_read: true])
  end

  @doc """
  Updates alert action taken.
  """
  def update_alert_action(%RiskAlart{} = alert, action) do
    alert
    |> RiskAlart.changeset(%{action_taken: action})
    |> Repo.update()
  end

  @doc """
  Creates a high risk visit alert.
  """
  def create_high_risk_visit_alert(user_id, site_id, risk_score, site_name) do
    message = "High risk site detected: #{site_name} (Risk Score: #{risk_score}%)"

    create_risk_alert(%{
      user_id: user_id,
      site_id: site_id,
      alert_type: "high_risk_visit",
      risk_score: risk_score,
      message: message
    })
  end

  @doc """
  Creates a preference violation alert.
  """
  def create_preference_violation_alert(user_id, site_id, violated_preferences, site_name) do
    preferences_text = violated_preferences |> Enum.join(", ")
    message = "#{site_name} violates your privacy preferences: #{preferences_text}"

    create_risk_alert(%{
      user_id: user_id,
      site_id: site_id,
      alert_type: "preference_violation",
      violated_preferences: violated_preferences,
      message: message
    })
  end

  @doc """
  Creates a new ToS detected alert.
  """
  def create_new_tos_alert(user_id, site_id, site_name) do
    message = "#{site_name} has updated their Terms of Service or Privacy Policy"

    create_risk_alert(%{
      user_id: user_id,
      site_id: site_id,
      alert_type: "new_tos_detected",
      message: message
    })
  end

  @doc """
  Gets alert statistics for a user.
  """
  def get_user_alert_statistics(user_id) do
    from(ra in RiskAlart,
      where: ra.user_id == ^user_id,
      group_by: ra.alert_type,
      select: {ra.alert_type, count(ra.id)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Gets recent high-risk alerts across all users (for admin dashboard).
  """
  def get_recent_high_risk_alerts(limit \\ 50) do
    from(ra in RiskAlart,
      join: u in User, on: u.id == ra.user_id,
      join: s in Site, on: s.id == ra.site_id,
      where: ra.alert_type == "high_risk_visit" and ra.risk_score >= 60,
      order_by: [desc: ra.inserted_at],
      limit: ^limit,
      select: {ra, u.email, s.domain}
    )
    |> Repo.all()
  end

  @doc """
  Deletes old alerts (cleanup function).
  """
  def delete_old_alerts(days_old \\ 30) do
    cutoff_date = NaiveDateTime.utc_now() |> NaiveDateTime.add(-days_old * 24 * 3600, :second)

    from(ra in RiskAlart, where: ra.inserted_at < ^cutoff_date)
    |> Repo.delete_all()
  end
end
