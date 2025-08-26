defmodule Sod.Repo.Migrations.CreateUserAnalysisHistory do
  use Ecto.Migration

   def change do
    create table(:user_analysis_history, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false
      add :tos_analysis_cache_id, references(:tos_analysis_cache, type: :binary_id, on_delete: :delete_all)

      add :personalized_risk_score, :integer
      add :violated_preferences, {:array, :string}
      add :personalized_warnings, {:array, :map}
      add :user_recommendation, :string
      add :analysis_requested_at, :naive_datetime, null: false

      add :user_decision, :string
      add :decision_made_at, :naive_datetime

      timestamps()
    end

    create index(:user_analysis_history, [:user_id])
    create index(:user_analysis_history, [:site_id])
    create index(:user_analysis_history, [:analysis_requested_at])
  end
end
