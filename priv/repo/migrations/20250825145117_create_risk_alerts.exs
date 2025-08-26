defmodule Sod.Repo.Migrations.CreateRiskAlerts do
  use Ecto.Migration

  def change do
    create table(:risk_alerts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all)
      add :alert_type, :string, null: false
      add :risk_score, :integer
      add :violated_preferences, {:array, :string}
      add :message, :text, null: false
      add :is_read, :boolean, default: false
      add :action_taken, :string

      timestamps()
    end

    create index(:risk_alerts, [:user_id])
    create index(:risk_alerts, [:site_id])
    create index(:risk_alerts, [:alert_type])
    create index(:risk_alerts, [:is_read])
  end
end
