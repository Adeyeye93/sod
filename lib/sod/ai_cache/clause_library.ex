defmodule Sod.AiCache.ClauseLibrary do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "clause_library" do
    field :clause_hash, :string  # Hash of the clause text
    field :clause_text, :string  # The actual clause text
    field :clause_summary, :string  # AI-generated summary
    field :risk_category, :string  # Category this clause belongs to
    field :risk_level, :string  # "low", "medium", "high", "critical"
    field :risk_score, :integer  # 1-100
    field :explanation, :string  # Why this clause is risky
    field :user_impact, :string  # How this affects users
    field :mitigation_advice, :string  # What users can do about it

    # Classification
    field :clause_type, :string  # "data_sharing", "retention", etc.
    field :keywords, {:array, :string}  # For search and matching
    field :language, :string, default: "en"

    # Usage tracking
    field :found_in_sites_count, :integer, default: 0
    field :last_seen_at, :naive_datetime
    field :created_by_ai_model, :string

    # Many-to-many with sites
    many_to_many :sites, Sod.Sites.Site,
      join_through: "site_clause_associations",
      join_keys: [clause_id: :id, site_id: :id]

    timestamps()
  end

  def changeset(clause_library, attrs) do
    clause_library
    |> cast(attrs, [
      :clause_hash, :clause_text, :clause_summary, :risk_category, :risk_level,
      :risk_score, :explanation, :user_impact, :mitigation_advice, :clause_type,
      :keywords, :language, :found_in_sites_count, :last_seen_at, :created_by_ai_model
    ])
    |> validate_required([:clause_hash, :clause_text, :risk_category, :risk_level])
    |> unique_constraint(:clause_hash)
    |> validate_inclusion(:risk_level, ["low", "medium", "high", "critical"])
    |> validate_number(:risk_score, greater_than_or_equal_to: 1, less_than_or_equal_to: 100)
  end
end
