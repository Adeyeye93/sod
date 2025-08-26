defmodule Sod.Analytics do
  @moduledoc """
  The Analytics context for risk analysis, site visits, and statistics.
  """

  import Ecto.Query, warn: false
  alias Sod.Repo
  alias Sod.Analytics.{SiteRiskAnalysis, SiteVisit, RiskStatistics}
  alias Sod.Sites.Site
  # alias Sod.Accounts.User

  # Site Risk Analysis functions

  @doc """
  Creates or updates a site risk analysis.
  """
  def upsert_site_risk_analysis(site_id, attrs) do
    case Repo.get_by(SiteRiskAnalysis, site_id: site_id) do
      nil ->
        %SiteRiskAnalysis{}
        |> SiteRiskAnalysis.changeset(Map.put(attrs, :site_id, site_id))
        |> Repo.insert()

      existing_analysis ->
        existing_analysis
        |> SiteRiskAnalysis.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Gets site risk analysis by site ID.
  """
  def get_site_risk_analysis(site_id) do
    Repo.get_by(SiteRiskAnalysis, site_id: site_id)
  end

  @doc """
  Gets sites by risk level.
  """
  def get_sites_by_risk_level(risk_level) do
    from(sra in SiteRiskAnalysis,
      join: s in Site, on: s.id == sra.site_id,
      where: sra.risk_level == ^risk_level,
      select: {s, sra}
    )
    |> Repo.all()
  end

  @doc """
  Gets risk level distribution.
  """
  def get_risk_level_distribution do
    from(sra in SiteRiskAnalysis,
      group_by: sra.risk_level,
      select: {sra.risk_level, count(sra.id)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Calculates risk level from score.
  """
  def calculate_risk_level(score) when is_integer(score) do
    case score do
      score when score >= 0 and score <= 10 -> "minimal"
      score when score >= 11 and score <= 25 -> "low"
      score when score >= 26 and score <= 40 -> "moderate"
      score when score >= 41 and score <= 60 -> "elevated"
      score when score >= 61 and score <= 80 -> "high"
      score when score >= 81 and score <= 100 -> "extreme"
      _ -> "unknown"
    end
  end

  @doc """
  Gets risk color from level.
  """
  def get_risk_color(risk_level) do
    case risk_level do
      "minimal" -> "#22c55e"  # Green
      "low" -> "#84cc16"      # Light Green / Yellow-Green
      "moderate" -> "#eab308"  # Yellow
      "elevated" -> "#f97316"  # Orange
      "high" -> "#ef4444"      # Red
      "extreme" -> "#7f1d1d"   # Dark Red / Black-Red
      _ -> "#6b7280"           # Gray
    end
  end

  # Site Visit functions

  @doc """
  Creates a site visit record.
  """
  def create_site_visit(attrs \\ %{}) do
    %SiteVisit{}
    |> SiteVisit.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets site visits for a user.
  """
  def get_user_site_visits(user_id, limit \\ 50) do
    from(sv in SiteVisit,
      join: s in Site, on: s.id == sv.site_id,
      where: sv.user_id == ^user_id,
      order_by: [desc: sv.visited_at],
      limit: ^limit,
      select: {sv, s}
    )
    |> Repo.all()
  end

  @doc """
  Gets site visit statistics for a user.
  """
  def get_user_visit_statistics(user_id) do
    from(sv in SiteVisit,
      join: sra in SiteRiskAnalysis, on: sra.site_id == sv.site_id,
      where: sv.user_id == ^user_id,
      group_by: sra.risk_level,
      select: {sra.risk_level, count(sv.id)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Gets most visited high-risk sites for a user.
  """
  def get_user_high_risk_sites(user_id, limit \\ 10) do
    from(sv in SiteVisit,
      join: s in Site, on: s.id == sv.site_id,
      join: sra in SiteRiskAnalysis, on: sra.site_id == s.id,
      where: sv.user_id == ^user_id and sra.risk_level in ["elevated", "high", "extreme"],
      group_by: [s.id, s.domain, s.name, sra.risk_level, sra.overall_risk_score],
      select: {s, sra, count(sv.id)},
      order_by: [desc: count(sv.id)],
      limit: ^limit
    )
    |> Repo.all()
  end

  # Risk Statistics functions

  @doc """
  Creates or updates daily risk statistics.
  """
  def upsert_daily_risk_statistics(date \\ Date.utc_today()) do
    distribution = get_risk_level_distribution()
    total_sites = Enum.sum(Map.values(distribution))

    attrs = %{
      date: date,
      minimal_risk_count: Map.get(distribution, "minimal", 0),
      low_risk_count: Map.get(distribution, "low", 0),
      moderate_risk_count: Map.get(distribution, "moderate", 0),
      elevated_risk_count: Map.get(distribution, "elevated", 0),
      high_risk_count: Map.get(distribution, "high", 0),
      extreme_risk_count: Map.get(distribution, "extreme", 0),
      total_sites_analyzed: total_sites,
      new_sites_added: count_new_sites_for_date(date)
    }

    case Repo.get_by(RiskStatistics, date: date) do
      nil ->
        %RiskStatistics{}
        |> RiskStatistics.changeset(attrs)
        |> Repo.insert()

      existing_stats ->
        existing_stats
        |> RiskStatistics.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Gets risk statistics for a date range.
  """
  def get_risk_statistics_for_range(start_date, end_date) do
    from(rs in RiskStatistics,
      where: rs.date >= ^start_date and rs.date <= ^end_date,
      order_by: [asc: rs.date]
    )
    |> Repo.all()
  end

  @doc """
  Gets the latest risk statistics.
  """
  def get_latest_risk_statistics do
    from(rs in RiskStatistics,
      order_by: [desc: rs.date],
      limit: 1
    )
    |> Repo.one()
  end

  defp count_new_sites_for_date(date) do
    start_datetime = date |> NaiveDateTime.new!(~T[00:00:00])
    end_datetime = date |> NaiveDateTime.new!(~T[23:59:59])

    from(s in Site,
      where: s.inserted_at >= ^start_datetime and s.inserted_at <= ^end_datetime
    )
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Gets trending risk statistics (comparing current period to previous).
  """
  def get_risk_trends(days \\ 7) do
    current_end = Date.utc_today()
    current_start = Date.add(current_end, -days + 1)
    previous_end = Date.add(current_start, -1)
    previous_start = Date.add(previous_end, -days + 1)

    current_stats = get_risk_statistics_for_range(current_start, current_end)
    previous_stats = get_risk_statistics_for_range(previous_start, previous_end)

    %{
      current: aggregate_risk_statistics(current_stats),
      previous: aggregate_risk_statistics(previous_stats),
      period_days: days
    }
  end

  defp aggregate_risk_statistics(stats_list) do
    Enum.reduce(stats_list, %{
      minimal_risk_count: 0,
      low_risk_count: 0,
      moderate_risk_count: 0,
      elevated_risk_count: 0,
      high_risk_count: 0,
      extreme_risk_count: 0,
      total_sites_analyzed: 0,
      new_sites_added: 0
    }, fn stats, acc ->
      %{
        minimal_risk_count: acc.minimal_risk_count + stats.minimal_risk_count,
        low_risk_count: acc.low_risk_count + stats.low_risk_count,
        moderate_risk_count: acc.moderate_risk_count + stats.moderate_risk_count,
        elevated_risk_count: acc.elevated_risk_count + stats.elevated_risk_count,
        high_risk_count: acc.high_risk_count + stats.high_risk_count,
        extreme_risk_count: acc.extreme_risk_count + stats.extreme_risk_count,
        total_sites_analyzed: max(acc.total_sites_analyzed, stats.total_sites_analyzed),
        new_sites_added: acc.new_sites_added + stats.new_sites_added
      }
    end)
  end
end
