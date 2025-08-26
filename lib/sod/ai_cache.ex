defmodule Sod.AiCache do
  @moduledoc """
  Context for managing AI analysis caching and clause library.
  """

  import Ecto.Query, warn: false
  alias Sod.Repo
  alias Sod.AiCache.{TosAnalysisCache, ClauseLibrary, UserAnalysisHistory}

  # TOS Analysis Cache functions

  @doc """
  Gets cached analysis by content hash and type.
  """
  def get_cached_analysis(content_hash, content_type) do
    case Repo.get_by(TosAnalysisCache, content_hash: content_hash, content_type: content_type) do
      nil -> nil
      cache ->
        # Update access tracking
        update_cache_access(cache)
        cache
    end
  end

  @doc """
  Creates a new cached analysis.
  """
  def create_cached_analysis(attrs) do
    %TosAnalysisCache{}
    |> TosAnalysisCache.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Checks if content analysis exists in cache.
  """
  def analysis_cached?(content_hash, content_type) do
    query = from(tac in TosAnalysisCache,
      where: tac.content_hash == ^content_hash and tac.content_type == ^content_type)

    Repo.exists?(query)
  end

  @doc """
  Updates cache access tracking.
  """
  def update_cache_access(%TosAnalysisCache{} = cache) do
    cache
    |> TosAnalysisCache.changeset(%{
      last_accessed_at: NaiveDateTime.utc_now(),
      access_count: cache.access_count + 1
    })
    |> Repo.update()
  end

  @doc """
  Marks cache entries as stale for re-analysis.
  """
  def mark_cache_stale(site_id) do
    from(tac in TosAnalysisCache, where: tac.site_id == ^site_id)
    |> Repo.update_all(set: [is_stale: true])
  end

  # Clause Library functions

  @doc """
  Creates or updates a clause in the library.
  """
  def upsert_clause(attrs) do
    clause_hash = attrs[:clause_hash] || generate_clause_hash(attrs[:clause_text])

    case Repo.get_by(ClauseLibrary, clause_hash: clause_hash) do
      nil ->
        attrs = Map.put(attrs, :clause_hash, clause_hash)
        %ClauseLibrary{}
        |> ClauseLibrary.changeset(attrs)
        |> Repo.insert()

      existing_clause ->
        existing_clause
        |> ClauseLibrary.changeset(Map.merge(attrs, %{
          found_in_sites_count: existing_clause.found_in_sites_count + 1,
          last_seen_at: NaiveDateTime.utc_now()
        }))
        |> Repo.update()
    end
  end

  @doc """
  Searches clauses by keywords or text similarity.
  """
  def search_clauses(search_term, limit \\ 10) do
    search_query = "%#{search_term}%"

    from(cl in ClauseLibrary,
      where: ilike(cl.clause_text, ^search_query) or
            ilike(cl.clause_summary, ^search_query) or
            fragment("? = ANY(?)", ^search_term, cl.keywords),
      order_by: [desc: cl.found_in_sites_count, desc: cl.risk_score],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Gets clauses by risk level.
  """
  def get_clauses_by_risk_level(risk_level) do
    from(cl in ClauseLibrary,
      where: cl.risk_level == ^risk_level,
      order_by: [desc: cl.risk_score, desc: cl.found_in_sites_count]
    )
    |> Repo.all()
  end

  # User Analysis History functions

  @doc """
  Creates user analysis history record.
  """
  def create_user_analysis_history(attrs) do
    %UserAnalysisHistory{}
    |> UserAnalysisHistory.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets user's analysis history for a site.
  """
  def get_user_site_analysis_history(user_id, site_id) do
    from(uah in UserAnalysisHistory,
      where: uah.user_id == ^user_id and uah.site_id == ^site_id,
      order_by: [desc: uah.analysis_requested_at]
    )
    |> Repo.all()
  end

  @doc """
  Updates user decision on analysis.
  """
  def update_user_decision(%UserAnalysisHistory{} = history, decision) do
    history
    |> UserAnalysisHistory.changeset(%{
      user_decision: decision,
      decision_made_at: NaiveDateTime.utc_now()
    })
    |> Repo.update()
  end

  # Utility functions

  defp generate_clause_hash(clause_text) when is_binary(clause_text) do
    :crypto.hash(:sha256, clause_text) |> Base.encode16(case: :lower)
  end

  @doc """
  Cleans up old cache entries to save space.
  """
  def cleanup_old_cache(days_old \\ 90) do
    cutoff_date = NaiveDateTime.utc_now() |> NaiveDateTime.add(-days_old * 24 * 3600, :second)

    from(tac in TosAnalysisCache,
      where: tac.last_accessed_at < ^cutoff_date and tac.access_count < 5
    )
    |> Repo.delete_all()
  end

  @doc """
  Gets cache statistics for monitoring.
  """
  def get_cache_statistics do
    total_entries = Repo.aggregate(TosAnalysisCache, :count)
    stale_entries = from(tac in TosAnalysisCache, where: tac.is_stale == true) |> Repo.aggregate(:count)
    total_tokens_saved = from(tac in TosAnalysisCache, select: sum(tac.tokens_used)) |> Repo.one() || 0
    total_clauses = Repo.aggregate(ClauseLibrary, :count)

    avg_confidence = from(tac in TosAnalysisCache, select: avg(tac.confidence_score)) |> Repo.one()

    %{
      total_cached_analyses: total_entries,
      stale_entries: stale_entries,
      cache_hit_potential: total_tokens_saved,
      total_clauses_identified: total_clauses,
      average_confidence: avg_confidence && Float.round(avg_confidence, 2)
    }
  end
  @doc """
  Returns recent analysis trends: number of analyses per day for the last `days` days.
  """
  def get_recent_analysis_trends(days \\ 7) do
    cutoff = NaiveDateTime.utc_now() |> NaiveDateTime.add(-days * 24 * 3600, :second)

    from(tac in TosAnalysisCache,
      where: tac.inserted_at >= ^cutoff,
      group_by: fragment("date(?)", tac.inserted_at),
      select: {fragment("date(?)", tac.inserted_at), count(tac.id)},
      order_by: [asc: fragment("date(?)", tac.inserted_at)]
    )
    |> Repo.all()
    |> Enum.map(fn {date, count} -> %{date: date, analyses: count} end)
  end
end
