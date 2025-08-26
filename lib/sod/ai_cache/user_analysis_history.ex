defmodule Sod.AiCache.UserAnalysisHistory do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_analysis_history" do
    belongs_to :user, Sod.Accounts.User
    belongs_to :site, Sod.Sites.Site
    belongs_to :tos_analysis_cache, Sod.AiCache.TosAnalysisCache

    # User-specific analysis
    field :personalized_risk_score, :integer  # Adjusted based on user preferences
    field :violated_preferences, {:array, :string}  # Which preferences are violated
    field :personalized_warnings, {:array, :map}  # Custom warnings for this user
    field :user_recommendation, :string  # "proceed", "caution", "avoid"
    field :analysis_requested_at, :naive_datetime

    # User interaction
    field :user_decision, :string  # "proceeded", "avoided", "ignored"
    field :decision_made_at, :naive_datetime

    timestamps()
  end

  def changeset(user_analysis_history, attrs) do
    user_analysis_history
    |> cast(attrs, [
      :user_id, :site_id, :tos_analysis_cache_id, :personalized_risk_score,
      :violated_preferences, :personalized_warnings, :user_recommendation,
      :analysis_requested_at, :user_decision, :decision_made_at
    ])
    |> validate_required([:user_id, :site_id, :analysis_requested_at])
    |> validate_inclusion(:user_recommendation, ["proceed", "caution", "avoid"])
    |> validate_inclusion(:user_decision, ["proceeded", "avoided", "ignored"])
  end
end
