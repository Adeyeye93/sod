defmodule Sod.Repo.Migrations.CreateRiskStatistics do
  use Ecto.Migration

  def change do
    create table(:risk_statistics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :date, :date, null: false
      add :minimal_risk_count, :integer, default: 0
      add :low_risk_count, :integer, default: 0
      add :moderate_risk_count, :integer, default: 0
      add :elevated_risk_count, :integer, default: 0
      add :high_risk_count, :integer, default: 0
      add :extreme_risk_count, :integer, default: 0
      add :total_sites_analyzed, :integer, default: 0
      add :new_sites_added, :integer, default: 0

      timestamps()
    end

    create unique_index(:risk_statistics, [:date])
  end
end
