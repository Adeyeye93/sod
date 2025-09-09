defmodule SodWeb.API.ScraperController do
  use SodWeb, :controller

  alias Sod.{Scraper, ContentExtractor, Sites, RiskAnalyzer}
  alias Sod.BackgroundJobs.AiAnalyzer

  @doc """
  Manually triggers scraping for a specific domain.
  """
  def scrape_site(conn, %{"domain" => domain}) do
    case Scraper.scrape_site(domain) do
      {:ok, scraped_content} ->
        # Analyze content quality
        content_analysis = analyze_scraped_content(scraped_content)

        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          domain: domain,
          scraped_content: format_scraped_content(scraped_content),
          content_analysis: content_analysis,
          scraped_at: DateTime.utc_now()
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          domain: domain,
          error: format_error_reason(reason),
          scraped_at: DateTime.utc_now()
        })
    end
  end

  @doc """
  Discovers TOS/Privacy Policy URLs for a domain without scraping content.
  """
  def discover_urls(conn, %{"domain" => domain}) do
    case Scraper.scrape_site(domain) do
      {:ok, content} ->
        # Extract just the URLs and metadata
        urls = Enum.reduce(content, %{}, fn {type, data}, acc ->
          Map.put(acc, type, %{
            url: data.url,
            scraped_at: data.scraped_at,
            content_length: String.length(data.content),
            content_preview: String.slice(data.content, 0, 200) <> "..."
          })
        end)

        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          domain: domain,
          discovered_urls: urls
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          domain: domain,
          error: format_error_reason(reason)
        })
    end
  end

  @doc """
  Analyzes a specific URL's content without storing it.
  """
  def analyze_url(conn, %{"url" => url} = params) do
    content_type = Map.get(params, "content_type", "terms_of_service")

    case Scraper.scrape_url(url, content_type) do
      {:ok, content_data} ->
        # Get the actual content
        {_, content_info} = Enum.at(content_data, 0)
        content = content_info.content

        # Analyze content quality
        quality_analysis = ContentExtractor.analyze_content_quality(content)

        # Detect document type
        {detected_type, confidence} = ContentExtractor.detect_document_type(content)

        # Extract sections
        sections = ContentExtractor.extract_sections(content)

        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          url: url,
          content_analysis: %{
            quality_analysis: quality_analysis,
            document_type: %{
              detected: detected_type,
              confidence: confidence,
              requested: content_type
            },
            sections: sections,
            content_length: String.length(content),
            content_preview: String.slice(content, 0, 500) <> "..."
          }
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          url: url,
          error: format_error_reason(reason)
        })
    end
  end

  @doc """
  Triggers analysis for a scraped site (scrape + analyze).
  """
  def scrape_and_analyze(conn, %{"domain" => domain} = params) do
    user_preferences = get_user_preferences(conn, params)

    case Scraper.scrape_site(domain) do
      {:ok, scraped_content} when map_size(scraped_content) > 0 ->
        # Get or create site
        {:ok, site} = Sites.get_or_create_site_by_domain(domain)

        # Analyze each content type
        analysis_results = Enum.reduce(scraped_content, %{}, fn {content_type, content_data}, acc ->
          case analyze_content(content_data.content, content_type, site.id, user_preferences) do
            {:ok, analysis} -> Map.put(acc, content_type, analysis)
            {:error, _} -> acc
          end
        end)

        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          domain: domain,
          site_id: site.id,
          scraped_content: format_scraped_content(scraped_content),
          analysis_results: analysis_results,
          analyzed_at: DateTime.utc_now()
        })

      {:ok, _empty_content} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          domain: domain,
          error: "No TOS or privacy policy content found"
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          domain: domain,
          error: format_error_reason(reason)
        })
    end
  end

  @doc """
  Gets scraping status and statistics.
  """
  def get_scraping_stats(conn, _params) do
    # Get recent scraping activity
    sites = Sites.list_sites()

    stats = %{
      total_sites: length(sites),
      sites_with_tos_url: Enum.count(sites, &(&1.tos_url != nil)),
      sites_with_privacy_url: Enum.count(sites, &(&1.privacy_policy_url != nil)),
      recently_crawled: Enum.count(sites, &recently_crawled?/1),
      needs_crawling: Enum.count(sites, &needs_crawling?/1)
    }

    recent_activity = sites
                     |> Enum.filter(&(&1.last_crawled_at != nil))
                     |> Enum.sort_by(&(&1.last_crawled_at), :desc)
                     |> Enum.take(10)
                     |> Enum.map(&format_site_activity/1)

    conn
    |> put_status(:ok)
    |> json(%{
      stats: stats,
      recent_activity: recent_activity,
      generated_at: DateTime.utc_now()
    })
  end

  @doc """
  Triggers background scraping for sites that need updating.
  """
  def trigger_background_scraping(conn, params) do
    limit = Map.get(params, "limit", "10") |> String.to_integer()

    sites_needing_crawl = Sites.get_sites_needing_crawl(24)
                         |> Enum.take(limit)

    # Trigger analysis for these sites
    results = Enum.map(sites_needing_crawl, fn site ->
      case AiAnalyzer.analyze_site_now(site.id) do
        {:ok, _analysis} -> {site.domain, :success}
        {:error, reason} -> {site.domain, {:error, reason}}
      end
    end)

    success_count = Enum.count(results, fn {_, status} -> status == :success end)
    error_count = length(results) - success_count

    conn
    |> put_status(:ok)
    |> json(%{
      triggered: true,
      sites_processed: length(results),
      success_count: success_count,
      error_count: error_count,
      results: Enum.map(results, fn {domain, status} ->
        %{domain: domain, status: format_result_status(status)}
      end),
      triggered_at: DateTime.utc_now()
    })
  end

  @doc """
  Validates and preprocesses content for analysis.
  """
  def preprocess_content(conn, %{"content" => content} = params) do
    content_type = Map.get(params, "content_type", "terms_of_service")

    # Analyze original content
    original_quality = ContentExtractor.analyze_content_quality(content)

    # Preprocess content
    processed_content = ContentExtractor.preprocess_content(content)

    # Analyze processed content
    processed_quality = ContentExtractor.analyze_content_quality(processed_content)

    # Validate content
    is_valid = Scraper.validate_content(processed_content, content_type)

    conn
    |> put_status(:ok)
    |> json(%{
      original_content: %{
        length: String.length(content),
        quality_analysis: original_quality
      },
      processed_content: %{
        content: processed_content,
        length: String.length(processed_content),
        quality_analysis: processed_quality
      },
      validation: %{
        is_valid: is_valid,
        content_type: content_type
      },
      improvements: generate_preprocessing_summary(original_quality, processed_quality)
    })
  end

  # Private helper functions

  defp analyze_scraped_content(scraped_content) do
    Enum.reduce(scraped_content, %{}, fn {type, data}, acc ->
      quality_analysis = ContentExtractor.analyze_content_quality(data.content)
      {detected_type, confidence} = ContentExtractor.detect_document_type(data.content)

      analysis = %{
        quality_analysis: quality_analysis,
        document_type: %{
          detected: detected_type,
          confidence: confidence
        },
        is_valid: Scraper.validate_content(data.content, Atom.to_string(type)),
        content_length: String.length(data.content)
      }

      Map.put(acc, type, analysis)
    end)
  end

  defp format_scraped_content(scraped_content) do
    Enum.reduce(scraped_content, %{}, fn {type, data}, acc ->
      formatted = %{
        url: data.url,
        content_length: String.length(data.content),
        content_preview: String.slice(data.content, 0, 200) <> "...",
        scraped_at: data.scraped_at
      }
      Map.put(acc, type, formatted)
    end)
  end

  defp format_error_reason(reason) do
    case reason do
      :timeout -> "Request timed out"
      :forbidden -> "Access forbidden (403)"
      :not_found -> "Content not found (404)"
      :domain_not_found -> "Domain not found"
      :content_too_large -> "Content exceeds size limit"
      :insufficient_content -> "Insufficient content found"
      :html_parse_error -> "Failed to parse HTML"
      {:http_error, status} -> "HTTP error: #{status}"
      {:request_failed, _} -> "Network request failed"
      _ -> "Unknown error: #{inspect(reason)}"
    end
  end

  defp get_user_preferences(conn, _) do
    session_token = get_req_header(conn, "x-session-token")

    case session_token do
      [token] when is_binary(token) ->
        # Try to get user preferences (implementation depends on your auth system)
        # For now, return nil to indicate no user preferences
        nil
      _ ->
        nil
    end
  end

  defp analyze_content(content, content_type, site_id, user_preferences) do
    case user_preferences do
      nil ->
        RiskAnalyzer.analyze_tos_content(content, content_type, site_id)
      preferences ->
        RiskAnalyzer.analyze_for_user(content, content_type, site_id, preferences)
    end
  end

  defp recently_crawled?(site) do
    case site.last_crawled_at do
      nil -> false
      datetime ->
        cutoff = NaiveDateTime.utc_now() |> NaiveDateTime.add(-24 * 3600, :second)
        NaiveDateTime.compare(datetime, cutoff) == :gt
    end
  end

  defp needs_crawling?(site) do
    case site.last_crawled_at do
      nil -> true
      datetime ->
        cutoff = NaiveDateTime.utc_now() |> NaiveDateTime.add(-7 * 24 * 3600, :second)
        NaiveDateTime.compare(datetime, cutoff) == :lt
    end
  end

  defp format_site_activity(site) do
    %{
      domain: site.domain,
      last_crawled_at: site.last_crawled_at,
      has_tos_url: site.tos_url != nil,
      has_privacy_url: site.privacy_policy_url != nil,
      tos_url: site.tos_url,
      privacy_policy_url: site.privacy_policy_url
    }
  end

  defp format_result_status(:success), do: "success"
  defp format_result_status({:error, reason}), do: "error: #{inspect(reason)}"
  defp format_result_status(status), do: inspect(status)

  defp generate_preprocessing_summary(original_quality, processed_quality) do
    improvements = []

    improvements = if processed_quality.quality_score > original_quality.quality_score do
      ["Quality score improved from #{Float.round(original_quality.quality_score, 2)} to #{Float.round(processed_quality.quality_score, 2)}" | improvements]
    else
      improvements
    end

    improvements = if processed_quality.metrics.word_count != original_quality.metrics.word_count do
      word_diff = processed_quality.metrics.word_count - original_quality.metrics.word_count
      change = if word_diff > 0, do: "increased", else: "decreased"
      ["Word count #{change} by #{abs(word_diff)} words" | improvements]
    else
      improvements
    end

    improvements = if length(processed_quality.recommendations) < length(original_quality.recommendations) do
      ["Reduced quality issues from #{length(original_quality.recommendations)} to #{length(processed_quality.recommendations)}" | improvements]
    else
      improvements
    end

    if length(improvements) == 0 do
      ["No significant improvements detected"]
    else
      improvements
    end
  end
end
