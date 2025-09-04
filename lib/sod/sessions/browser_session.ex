defmodule Sod.Sessions.BrowserSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "browser_sessions" do
    belongs_to :user, Sod.Accounts.User

    field :session_token, :string
    field :browser_fingerprint, :string
    field :user_agent, :string
    field :ip_address, :string
    field :extension_version, :string
    field :is_active, :boolean, default: true
    field :last_activity, :naive_datetime

    has_many :site_visits, Sod.Analytics.SiteVisit

    timestamps()
  end

  def changeset(browser_session, attrs) do
    browser_session
    |> cast(attrs, [:user_id, :session_token, :browser_fingerprint, :user_agent, :ip_address, :extension_version, :is_active, :last_activity])
    |> validate_required([:session_token, :browser_fingerprint])
    |> unique_constraint(:session_token)
  end
end
