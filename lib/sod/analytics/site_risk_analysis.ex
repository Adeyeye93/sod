defmodule Sod.Analytics.SiteRiskAnalysis do
   use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "site_risk_analyses" do
    belongs_to :site, Sod.Sites.Site

    field :overall_risk_score, :integer # 0-100
    field :risk_level, :string # "minimal", "low", "moderate", "elevated", "high", "extreme"
    field :risk_color, :string # color code for UI

    # Risk category scores
    field :data_sharing_score, :integer
    field :data_collection_score, :integer
    field :personalization_tracking_score, :integer
    field :data_retention_score, :integer
    field :employee_access_score, :integer
    field :cross_border_transfer_score, :integer
    field :security_practices_score, :integer
    field :ai_concerns_score, :integer
    field :communication_score, :integer
    field :miscellaneous_risks_score, :integer

    # Detected risky practices (JSON field)
    field :detected_practices, :map

    field :analysis_date, :naive_datetime
    field :ai_model_version, :string

    timestamps()
  end

  def changeset(site_risk_analysis, attrs) do
    site_risk_analysis
    |> cast(attrs, [
      :overall_risk_score, :risk_level, :risk_color,
      :data_sharing_score, :data_collection_score, :personalization_tracking_score,
      :data_retention_score, :employee_access_score, :cross_border_transfer_score,
      :security_practices_score, :ai_concerns_score, :communication_score,
      :miscellaneous_risks_score, :detected_practices, :analysis_date, :ai_model_version
    ])
    |> validate_required([:overall_risk_score, :risk_level, :analysis_date])
    |> validate_inclusion(:overall_risk_score, 0..100)
    |> validate_inclusion(:risk_level, ["minimal", "low", "moderate", "elevated", "high", "extreme"])
  end
end
