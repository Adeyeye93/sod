defmodule Sod.Repo.Migrations.CreateSiteClauseAssociations do
  use Ecto.Migration

  def change do
    create table(:site_clause_associations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false
      add :clause_id, references(:clause_library, type: :binary_id, on_delete: :delete_all), null: false
      add :clause_position, :integer  # Where in document this clause appears
      add :section_name, :string  # Which section of TOS this is from

      timestamps()
    end

    create unique_index(:site_clause_associations, [:site_id, :clause_id])
    create index(:site_clause_associations, [:site_id])
    create index(:site_clause_associations, [:clause_id])
  end
end
