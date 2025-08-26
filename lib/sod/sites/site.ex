defmodule Sod.Sites.Site do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "sites" do
    field :domain, :string
    field :name, :string
    field :favicon_url, :string
    field :tos_url, :string
    field :privacy_policy_url, :string
    field :last_crawled_at, :naive_datetime
    field :is_active, :boolean, default: true

    has_one :site_risk_analysis, Sod.Analytics.SiteRiskAnalysis
    has_many :site_visits, Sod.Analytics.SiteVisit
    has_many :tos_versions, Sod.Sites.TosVersion

    timestamps()
  end

  def changeset(site, attrs) do
    site
    |> cast(attrs, [:domain, :name, :favicon_url, :tos_url, :privacy_policy_url, :last_crawled_at, :is_active])
    |> validate_required([:domain])
    |> unique_constraint(:domain)
    |> validate_format(:domain, ~r/^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?\.[a-zA-Z]{2,}$/)
  end
end
