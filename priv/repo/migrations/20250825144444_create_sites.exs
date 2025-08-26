defmodule Sod.Repo.Migrations.CreateSites do
  use Ecto.Migration

  def change do
    create table(:sites, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :domain, :string, null: false
      add :name, :string
      add :favicon_url, :string
      add :tos_url, :string
      add :privacy_policy_url, :string
      add :last_crawled_at, :naive_datetime
      add :is_active, :boolean, default: true

      timestamps()
    end

    create unique_index(:sites, [:domain])
    create index(:sites, [:last_crawled_at])
  end
end
