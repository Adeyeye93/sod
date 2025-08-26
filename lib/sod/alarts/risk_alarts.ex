defmodule Sod.Alarts.RiskAlarts do
   use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "risk_alerts" do
    belongs_to :user, Sod.Accounts.User
    belongs_to :site, Sod.Sites.Site

    field :alert_type, :string # "high_risk_visit", "preference_violation", "new_tos_detected"
    field :risk_score, :integer
    field :violated_preferences, {:array, :string} # array of preference field names
    field :message, :string
    field :is_read, :boolean, default: false
    field :action_taken, :string # "ignored", "blocked", "proceeded_anyway"

    timestamps()
  end

  def changeset(risk_alert, attrs) do
    risk_alert
    |> cast(attrs, [:alert_type, :risk_score, :violated_preferences, :message, :is_read, :action_taken])
    |> validate_required([:alert_type, :message])
  end
end
