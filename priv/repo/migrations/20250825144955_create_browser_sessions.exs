defmodule Sod.Repo.Migrations.CreateBrowserSessions do
  use Ecto.Migration

  def change do
    create table(:browser_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :session_token, :string, null: false
      add :browser_fingerprint, :string, null: false
      add :user_agent, :string
      add :ip_address, :string
      add :extension_version, :string
      add :is_active, :boolean, default: true
      add :last_activity, :naive_datetime

      timestamps()
    end

    create unique_index(:browser_sessions, [:session_token])
    create index(:browser_sessions, [:user_id])
    create index(:browser_sessions, [:browser_fingerprint])
    create index(:browser_sessions, [:is_active])
  end
end
