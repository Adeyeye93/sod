defmodule Sod.Analytics.RiskStatistics do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "risk_statistics" do
    field :date, :date
    field :minimal_risk_count, :integer, default: 0
    field :low_risk_count, :integer, default: 0
    field :moderate_risk_count, :integer, default: 0
    field :elevated_risk_count, :integer, default: 0
    field :high_risk_count, :integer, default: 0
    field :extreme_risk_count, :integer, default: 0
    field :total_sites_analyzed, :integer, default: 0
    field :new_sites_added, :integer, default: 0

    timestamps()
  end

  def changeset(risk_statistics, attrs) do
    risk_statistics
    |> cast(attrs, [
      :date, :minimal_risk_count, :low_risk_count, :moderate_risk_count,
      :elevated_risk_count, :high_risk_count, :extreme_risk_count,
      :total_sites_analyzed, :new_sites_added
    ])
    |> validate_required([:date])
    |> unique_constraint(:date)
  end
end
