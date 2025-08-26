defmodule Sod.AiCache.TosAnalysisCache do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tos_analysis_cache" do
    belongs_to :site, Sod.Sites.Site

    # Content identification
    field :content_hash, :string  # SHA-256 hash of the content
    field :content_type, :string  # "terms_of_service" | "privacy_policy" | "combined"
    field :content_length, :integer
    field :language, :string, default: "en"

    # AI Analysis Results (JSON)
    field :risk_analysis, :map  # Complete risk breakdown
    field :detected_clauses, :map  # Specific problematic clauses with locations
    field :risk_explanations, :map  # Human-readable explanations for each risk
    field :recommendation_summary, :string  # Overall recommendation

    # Analysis metadata
    field :ai_model_used, :string  # "gpt-4", "claude-3", etc.
    field :analysis_version, :string  # Version of analysis logic
    field :tokens_used, :integer  # Track token consumption
    field :analysis_duration_ms, :integer  # Performance tracking
    field :confidence_score, :float  # AI confidence in analysis (0.0 - 1.0)

    # Cache management
    field :analyzed_at, :naive_datetime
    field :last_accessed_at, :naive_datetime
    field :access_count, :integer, default: 0
    field :is_stale, :boolean, default: false  # Mark for re-analysis if needed

    timestamps()
  end

  def changeset(tos_analysis_cache, attrs) do
    tos_analysis_cache
    |> cast(attrs, [
      :site_id, :content_hash, :content_type, :content_length, :language,
      :risk_analysis, :detected_clauses, :risk_explanations, :recommendation_summary,
      :ai_model_used, :analysis_version, :tokens_used, :analysis_duration_ms,
      :confidence_score, :analyzed_at, :last_accessed_at, :access_count, :is_stale
    ])
    |> validate_required([:content_hash, :content_type, :risk_analysis, :analyzed_at])
    |> validate_inclusion(:content_type, ["terms_of_service", "privacy_policy", "combined"])
    |> validate_number(:confidence_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
  end
end
