defmodule Sod.Analytics.SiteVisit do
   use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "site_visits" do
    belongs_to :user, Sod.Accounts.User
    belongs_to :site, Sod.Sites.Site
    belongs_to :browser_session, Sod.Sessions.BrowserSession

    field :visited_at, :naive_datetime
    field :url, :string
    field :user_agent, :string
    field :duration_seconds, :integer
    field :risk_alert_shown, :boolean, default: false
    field :user_proceeded, :boolean # did user proceed after seeing warning

    timestamps()
  end

  def changeset(site_visit, attrs) do
    site_visit
    |> cast(attrs, [:visited_at, :url, :user_agent, :duration_seconds, :risk_alert_shown, :user_proceeded])
    |> validate_required([:visited_at, :url])
  end
end
