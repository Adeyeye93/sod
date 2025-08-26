defmodule Sod.Repo.Migrations.CreateTosAnalysisCache do
  use Ecto.Migration

   def change do
    create table(:tos_analysis_cache, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all)

      add :content_hash, :string, null: false
      add :content_type, :string, null: false
      add :content_length, :integer
      add :language, :string, default: "en"

      add :risk_analysis, :map
      add :detected_clauses, :map
      add :risk_explanations, :map
      add :recommendation_summary, :text

      add :ai_model_used, :string
      add :analysis_version, :string
      add :tokens_used, :integer
      add :analysis_duration_ms, :integer
      add :confidence_score, :float

      add :analyzed_at, :naive_datetime, null: false
      add :last_accessed_at, :naive_datetime
      add :access_count, :integer, default: 0
      add :is_stale, :boolean, default: false

      timestamps()
    end

    create unique_index(:tos_analysis_cache, [:content_hash, :content_type])
    create index(:tos_analysis_cache, [:site_id])
    create index(:tos_analysis_cache, [:analyzed_at])
    create index(:tos_analysis_cache, [:last_accessed_at])
    create index(:tos_analysis_cache, [:is_stale])
  end
end
