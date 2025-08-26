defmodule Sod.Repo.Migrations.CreateSiteRiskAnalyses do
  use Ecto.Migration

  def change do
    create table(:site_risk_analyses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false
      add :overall_risk_score, :integer, null: false
      add :risk_level, :string, null: false
      add :risk_color, :string

      # Risk category scores
      add :data_sharing_score, :integer
      add :data_collection_score, :integer
      add :personalization_tracking_score, :integer
      add :data_retention_score, :integer
      add :employee_access_score, :integer
      add :cross_border_transfer_score, :integer
      add :security_practices_score, :integer
      add :ai_concerns_score, :integer
      add :communication_score, :integer
      add :miscellaneous_risks_score, :integer

      add :detected_practices, :map
      add :analysis_date, :naive_datetime, null: false
      add :ai_model_version, :string

      timestamps()
    end

    create unique_index(:site_risk_analyses, [:site_id])
    create index(:site_risk_analyses, [:risk_level])
    create index(:site_risk_analyses, [:overall_risk_score])
    create index(:site_risk_analyses, [:analysis_date])
  end
end
