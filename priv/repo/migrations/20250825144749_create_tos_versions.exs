defmodule Sod.Repo.Migrations.CreateTosVersions do
  use Ecto.Migration

  def change do
    create table(:tos_versions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false
      add :version_hash, :string, null: false
      add :content, :text
      add :content_type, :string, null: false
      add :detected_at, :naive_datetime, null: false
      add :is_current, :boolean, default: true

      timestamps()
    end

    create index(:tos_versions, [:site_id])
    create index(:tos_versions, [:version_hash])
    create index(:tos_versions, [:detected_at])
    create index(:tos_versions, [:is_current])
  end
end
