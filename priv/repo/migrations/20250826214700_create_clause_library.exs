defmodule Sod.Repo.Migrations.CreateClauseLibrary do
  use Ecto.Migration

  def change do
    create table(:clause_library, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :clause_hash, :string, null: false
      add :clause_text, :text, null: false
      add :clause_summary, :text
      add :risk_category, :string, null: false
      add :risk_level, :string, null: false
      add :risk_score, :integer
      add :explanation, :text
      add :user_impact, :text
      add :mitigation_advice, :text

      add :clause_type, :string
      add :keywords, {:array, :string}
      add :language, :string, default: "en"

      add :found_in_sites_count, :integer, default: 0
      add :last_seen_at, :naive_datetime
      add :created_by_ai_model, :string

      timestamps()
    end

    create unique_index(:clause_library, [:clause_hash])
    create index(:clause_library, [:risk_category])
    create index(:clause_library, [:risk_level])
    create index(:clause_library, [:clause_type])
    create index(:clause_library, [:keywords], using: :gin)
  end

end
