defmodule Sod.RiskAnalyzer do
  @moduledoc """
  Enhanced risk analysis with AI caching and advanced features.
  """

  alias Sod.Analytics
  alias Sod.Preference.UserPreference
  alias Sod.Ai.LangchainAnalyzer
  alias Sod.AiCache

  @doc """
  Main entry point for analyzing TOS content with caching.
  """
  def analyze_tos_content(content, content_type, site_id, options \\ []) do
    case LangchainAnalyzer.analyze_tos_content(content, content_type, site_id, options) do
      {:ok, :cached, analysis} ->
        # Convert cached analysis to the format expected by existing code
        {:ok, convert_cached_to_analysis_format(analysis)}

      {:ok, :fresh, analysis} ->
        # Fresh analysis from AI
        {:ok, convert_cached_to_analysis_format(analysis)}

      {:error, _reason} ->
        # Fallback to rule-based analysis if AI fails
        {:ok, fallback_rule_based_analysis(content, content_type)}
    end
  end

  @doc """
  Analyzes content for a specific user with personalized recommendations.
  """
  def analyze_for_user(content, content_type, site_id, %UserPreference{} = user_preferences) do
    case LangchainAnalyzer.analyze_for_user(content, content_type, user_preferences, site_id) do
      {:ok, source, personalized_analysis} ->
        # Create alerts if necessary
        maybe_create_alerts(user_preferences, personalized_analysis, site_id)

        {:ok, source, personalized_analysis}

      error -> error
    end
  end

  @doc """
  Bulk analysis for multiple sites (useful for background processing).
  """
  def bulk_analyze_sites(sites, options \\ []) do
    concurrency = Keyword.get(options, :concurrency, 5)
    timeout = Keyword.get(options, :timeout, 30_000)

    sites
    |> Task.async_stream(
      fn site ->
        analyze_site_tos(site, options)
      end,
      max_concurrency: concurrency,
      timeout: timeout,
      on_timeout: :kill_task
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, :timeout} -> {:error, :timeout}
    end)
  end

  @doc """
  Gets analysis summary for admin dashboard.
  """
  def get_analysis_summary do
    cache_stats = AiCache.get_cache_statistics()

    # Get recent analysis trends
    recent_analyses = AiCache.get_recent_analysis_trends(7)

    # Get most problematic clauses
    high_risk_clauses = AiCache.get_clauses_by_risk_level("high")
                       |> Enum.take(10)

    %{
      cache_statistics: cache_stats,
      recent_trends: recent_analyses,
      top_risk_clauses: high_risk_clauses,
      analysis_efficiency: calculate_analysis_efficiency(cache_stats)
    }
  end

  @doc """
  Identifies similar clauses across different sites.
  """
  def find_similar_clauses(clause_text, similarity_threshold \\ 0.8) do
    # This would use more sophisticated text similarity matching
    AiCache.search_clauses(clause_text, 20)
    |> Enum.filter(fn clause ->
      similarity = calculate_text_similarity(clause_text, clause.clause_text)
      similarity >= similarity_threshold
    end)
  end

  # Private helper functions

  defp convert_cached_to_analysis_format(cached_analysis) do
    risk_analysis = cached_analysis.risk_analysis || %{}

    %{
      overall_risk_score: risk_analysis["overall_risk_score"] || 0,
      risk_level: Analytics.calculate_risk_level(risk_analysis["overall_risk_score"] || 0),
      risk_color: Analytics.get_risk_color(Analytics.calculate_risk_level(risk_analysis["overall_risk_score"] || 0)),
      data_sharing_score: risk_analysis["data_sharing"] || 0,
      data_collection_score: risk_analysis["data_collection"] || 0,
      personalization_tracking_score: risk_analysis["personalization_tracking"] || 0,
      data_retention_score: risk_analysis["data_retention"] || 0,
      employee_access_score: risk_analysis["employee_access"] || 0,
      cross_border_transfer_score: risk_analysis["cross_border_transfer"] || 0,
      security_practices_score: risk_analysis["security_practices"] || 0,
      ai_concerns_score: risk_analysis["ai_concerns"] || 0,
      communication_score: risk_analysis["communication"] || 0,
      miscellaneous_risks_score: risk_analysis["miscellaneous_risks"] || 0,
      detected_practices: build_detected_practices_map(cached_analysis.detected_clauses),
      analysis_date: cached_analysis.analyzed_at,
      ai_model_version: cached_analysis.ai_model_used,
      confidence_score: cached_analysis.confidence_score,
      recommendation_summary: cached_analysis.recommendation_summary
    }
  end

  defp build_detected_practices_map(detected_clauses) when is_list(detected_clauses) do
    # Convert detected clauses to the boolean map format expected by existing code
    Enum.reduce(detected_clauses, %{}, fn clause, acc ->
      # Map clause categories to practice flags
      practices = map_clause_to_practices(clause)
      Map.merge(acc, practices)
    end)
  end
  defp build_detected_practices_map(_), do: %{}

  defp map_clause_to_practices(clause) do
    case clause["risk_category"] do
      "data_sharing" -> %{
        "allow_data_selling" => String.contains?(clause["clause_text"], ["sell", "selling"]),
        "allow_third_party_sharing" => String.contains?(clause["clause_text"], ["third party", "partners"])
      }
      "data_collection" -> %{
        "allow_precise_location" => String.contains?(clause["clause_text"], ["location", "gps"]),
        "allow_camera_access" => String.contains?(clause["clause_text"], ["camera", "photos"]),
        "allow_microphone_access" => String.contains?(clause["clause_text"], ["microphone", "audio"])
      }
      # Add other category mappings...
      _ -> %{}
    end
  end

  defp fallback_rule_based_analysis(content, _content_type) do
    # Simple rule-based analysis as fallback when AI is unavailable
    content_lower = String.downcase(content)

    risk_indicators = [
      {"sell", 20}, {"third party", 15}, {"marketing", 10},
      {"track", 15}, {"cookies", 5}, {"location", 15},
      {"camera", 20}, {"microphone", 20}, {"contacts", 15}
    ]

    total_risk = Enum.reduce(risk_indicators, 0, fn {keyword, weight}, acc ->
      if String.contains?(content_lower, keyword), do: acc + weight, else: acc
    end)

    risk_score = min(100, total_risk)

    %{
      overall_risk_score: risk_score,
      risk_level: Analytics.calculate_risk_level(risk_score),
      risk_color: Analytics.get_risk_color(Analytics.calculate_risk_level(risk_score)),
      detected_practices: %{},
      analysis_date: NaiveDateTime.utc_now(),
      ai_model_version: "fallback_v1.0",
      confidence_score: 0.5,
      recommendation_summary: "Basic rule-based analysis - consider manual review"
    }
  end

  defp analyze_site_tos(site, options) do
    # This would fetch the actual TOS content from the site
    # For now, using mock content
    mock_content = "Mock TOS content for #{site.domain}"

    case analyze_tos_content(mock_content, "terms_of_service", site.id, options) do
      {:ok, analysis} ->
        # Update site risk analysis in database
        Analytics.upsert_site_risk_analysis(site.id, analysis)
        {:ok, site.domain, analysis}
        
      #TODO: Handle specific error cases from analysis
      # _error ->
      #   {:error, site.domain, :analysis_failed}
    end
  end

  defp maybe_create_alerts(user_preferences, personalized_analysis, site_id) do
    case personalized_analysis.user_recommendation do
      "avoid" ->
        Sod.Alerts.create_high_risk_visit_alert(
          user_preferences.user_id,
          site_id,
          personalized_analysis.personalized_risk_score,
          "High-risk site"
        )

      "caution" when length(personalized_analysis.violated_preferences) != [] ->
        Sod.Alerts.create_preference_violation_alert(
          user_preferences.user_id,
          site_id,
          personalized_analysis.violated_preferences,
          "Site with preference violations"
        )

      _ -> :ok
    end
  end

  defp calculate_analysis_efficiency(cache_stats) do
    total_analyses = cache_stats.total_cached_analyses
    potential_tokens_saved = cache_stats.cache_hit_potential

    if total_analyses > 0 do
      efficiency_ratio = potential_tokens_saved / (total_analyses * 1000)  # Assume avg 1000 tokens per analysis
      %{
        cache_hit_ratio: Float.round(efficiency_ratio * 100, 2),
        tokens_saved: potential_tokens_saved,
        cost_saved_estimate: potential_tokens_saved * 0.002  # Rough cost estimate
      }
    else
      %{cache_hit_ratio: 0, tokens_saved: 0, cost_saved_estimate: 0}
    end
  end

  defp calculate_text_similarity(text1, text2) do
    # Simple Jaccard similarity - you could use more sophisticated algorithms
    words1 = text1 |> String.downcase() |> String.split() |> MapSet.new()
    words2 = text2 |> String.downcase() |> String.split() |> MapSet.new()

    intersection = MapSet.intersection(words1, words2) |> MapSet.size()
    union = MapSet.union(words1, words2) |> MapSet.size()

    if union > 0, do: intersection / union, else: 0.0
  end
end
