defmodule Sod.Repo.Migrations.CreateSiteVisits do
  use Ecto.Migration

   def change do
    create table(:site_visits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false
      add :browser_session_id, references(:browser_sessions, type: :binary_id, on_delete: :delete_all)
      add :visited_at, :naive_datetime, null: false
      add :url, :string, null: false
      add :user_agent, :string
      add :duration_seconds, :integer
      add :risk_alert_shown, :boolean, default: false
      add :user_proceeded, :boolean

      timestamps()
    end

    create index(:site_visits, [:user_id])
    create index(:site_visits, [:site_id])
    create index(:site_visits, [:visited_at])
    create index(:site_visits, [:risk_alert_shown])
  end
end
