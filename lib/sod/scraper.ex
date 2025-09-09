defmodule Sod.Scraper do
  @moduledoc """
  Web scraper for extracting Terms of Service and Privacy Policy content from websites.

  This module handles:
  - Finding TOS/Privacy Policy URLs
  - Scraping content from discovered URLs
  - Content cleaning and preprocessing
  - Rate limiting and error handling
  """

  require Logger
  alias Sod.Sites

  # Common TOS/Privacy Policy URL patterns
  @tos_patterns [
    "terms-of-service", "terms-and-conditions", "terms", "tos",
    "user-agreement", "service-terms", "legal/terms",
    "terms-of-use", "conditions-of-use"
  ]

  @privacy_patterns [
    "privacy-policy", "privacy", "privacy-statement",
    "data-protection", "legal/privacy", "privacy-notice"
  ]

  @user_agent "Sod Privacy Analyzer Bot/1.0 (https://yoursite.com/bot)"
  @request_timeout 30_000
  @max_content_size 5_000_000  # 5MB limit
  @rate_limit_delay 1000  # 1 second between requests

  @doc """
  Scrapes TOS and Privacy Policy content for a given domain.

  Returns:
  - `{:ok, results}` - Successfully scraped content
  - `{:error, reason}` - Failed to scrape
  """
  def scrape_site(domain) when is_binary(domain) do
    Logger.info("Starting scrape for domain: #{domain}")

    with {:ok, base_url} <- normalize_domain(domain),
         {:ok, html} <- fetch_homepage(base_url),
         {:ok, urls} <- discover_legal_urls(html, base_url),
         {:ok, content} <- scrape_legal_content(urls, base_url) do

      # Update site record with discovered URLs
      update_site_urls(domain, urls)

      Logger.info("Successfully scraped #{domain}: #{map_size(content)} documents found")
      {:ok, content}
    else
      {:error, reason} = error ->
        Logger.warning("Failed to scrape #{domain}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Scrapes content from a specific URL (used when TOS/Privacy URLs are already known).
  """
  def scrape_url(url, content_type \\ "terms_of_service") do
    Logger.info("Scraping specific URL: #{url}")

    case fetch_page_content(url) do
      {:ok, html} ->
        content = extract_main_content(html)
        if String.length(content) > 100 do
          {:ok, %{content_type => %{url: url, content: content, scraped_at: DateTime.utc_now()}}}
        else
          {:error, :insufficient_content}
        end

      error -> error
    end
  end

  @doc """
  Discovers TOS and Privacy Policy URLs from a website's homepage.
  """
  def discover_legal_urls(html, base_url) when is_binary(html) and is_binary(base_url) do
    try do
      {:ok, document} = Floki.parse_document(html)

      links = Floki.find(document, "a")
              |> Floki.attribute("href")
              |> Enum.map(&resolve_url(&1, base_url))
              |> Enum.reject(&is_nil/1)

      tos_urls = find_matching_urls(links, @tos_patterns)
      privacy_urls = find_matching_urls(links, @privacy_patterns)

      urls = %{}
      urls = if length(tos_urls) > 0, do: Map.put(urls, :terms_of_service, List.first(tos_urls)), else: urls
      urls = if length(privacy_urls) > 0, do: Map.put(urls, :privacy_policy, List.first(privacy_urls)), else: urls

      if map_size(urls) > 0 do
        {:ok, urls}
      else
        # Fallback: try common paths
        {:ok, try_common_paths(base_url)}
      end
    rescue
      error ->
        Logger.warning("Error parsing HTML for URL discovery: #{inspect(error)}")
        {:error, :html_parse_error}
    end
  end

  @doc """
  Extracts main content from HTML, removing navigation, headers, footers, etc.
  """
  def extract_main_content(html) when is_binary(html) do
    try do
      {:ok, document} = Floki.parse_document(html)

      # Try to find main content areas in order of preference
      content_selectors = [
        "main",
        "[role=\"main\"]",
        ".content",
        "#content",
        ".main-content",
        ".page-content",
        "article",
        ".post-content",
        ".entry-content"
      ]

      content = Enum.find_value(content_selectors, fn selector ->
        case Floki.find(document, selector) do
          [] -> nil
          elements -> Floki.text(elements)
        end
      end)

      # Fallback to body if no specific content area found
      content = content || Floki.find(document, "body") |> Floki.text()

      # Clean up the content
      content
      |> String.trim()
      |> clean_whitespace()
      |> remove_common_navigation_text()
    rescue
      error ->
        Logger.warning("Error extracting content from HTML: #{inspect(error)}")
        ""
    end
  end

  # Private helper functions

  defp normalize_domain(domain) do
    domain = String.trim(domain)

    cond do
      String.starts_with?(domain, "http") -> {:ok, domain}
      true -> {:ok, "https://#{domain}"}
    end
  end

  defp fetch_homepage(base_url) do
    fetch_page_content(base_url)
  end

  defp fetch_page_content(url) do
    headers = [
      {"User-Agent", @user_agent},
      {"Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"},
      {"Accept-Language", "en-US,en;q=0.5"},
      {"Accept-Encoding", "gzip, deflate"},
      {"DNT", "1"},
      {"Connection", "keep-alive"},
      {"Upgrade-Insecure-Requests", "1"}
    ]

    # Add rate limiting
    Process.sleep(@rate_limit_delay)

    case Finch.build(:get, url, headers) |> Finch.request(Sod.Finch, receive_timeout: @request_timeout) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        if byte_size(body) > @max_content_size do
          {:error, :content_too_large}
        else
          {:ok, body}
        end

      {:ok, %Finch.Response{status: status}} when status in [301, 302, 303, 307, 308] ->
        {:error, :redirect_not_followed}

      {:ok, %Finch.Response{status: 403}} ->
        {:error, :forbidden}

      {:ok, %Finch.Response{status: 404}} ->
        {:error, :not_found}

      {:ok, %Finch.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, %Mint.TransportError{reason: :timeout}} ->
        {:error, :timeout}

      {:error, %Mint.TransportError{reason: :nxdomain}} ->
        {:error, :domain_not_found}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp scrape_legal_content(urls, _base_url) when map_size(urls) == 0 do
    {:ok, %{}}
  end

  defp scrape_legal_content(urls, _base_url) do
    results = Enum.reduce(urls, %{}, fn {type, url}, acc ->
      case scrape_url(url, Atom.to_string(type)) do
        {:ok, content} -> Map.merge(acc, content)
        {:error, reason} ->
          Logger.warning("Failed to scrape #{type} from #{url}: #{inspect(reason)}")
          acc
      end
    end)

    {:ok, results}
  end

  defp find_matching_urls(links, patterns) do
    Enum.filter(links, fn url ->
      url_lower = String.downcase(url)
      Enum.any?(patterns, &String.contains?(url_lower, &1))
    end)
    |> Enum.take(3)  # Limit to first 3 matches to avoid too many requests
  end

  defp resolve_url(relative_url, base_url) when is_binary(relative_url) do
    cond do
      String.starts_with?(relative_url, "http") -> relative_url
      String.starts_with?(relative_url, "//") -> "https:#{relative_url}"
      String.starts_with?(relative_url, "/") ->
        %URI{scheme: scheme, host: host} = URI.parse(base_url)
        "#{scheme}://#{host}#{relative_url}"
      String.starts_with?(relative_url, "#") -> nil  # Skip anchor links
      String.contains?(relative_url, "javascript:") -> nil  # Skip JavaScript links
      true ->
        base_uri = URI.parse(base_url)
        URI.to_string(%{base_uri | path: Path.join(base_uri.path || "/", relative_url)})
    end
  rescue
    _ -> nil
  end

  defp try_common_paths(base_url) do
    common_paths = [
      {"/terms", :terms_of_service},
      {"/terms-of-service", :terms_of_service},
      {"/tos", :terms_of_service},
      {"/legal/terms", :terms_of_service},
      {"/privacy", :privacy_policy},
      {"/privacy-policy", :privacy_policy},
      {"/legal/privacy", :privacy_policy}
    ]

    Enum.reduce(common_paths, %{}, fn {path, type}, acc ->
      full_url = base_url <> path
      # We'll just return the URLs here, actual scraping will happen later
      # to avoid too many HTTP requests during discovery
      Map.put(acc, type, full_url)
    end)
  end

  defp update_site_urls(domain, urls) do
    case Sites.get_site_by_domain(domain) do
      nil ->
        Sites.create_site(%{
          domain: domain,
          tos_url: urls[:terms_of_service],
          privacy_policy_url: urls[:privacy_policy],
          last_crawled_at: NaiveDateTime.utc_now()
        })

      site ->
        Sites.update_site(site, %{
          tos_url: urls[:terms_of_service] || site.tos_url,
          privacy_policy_url: urls[:privacy_policy] || site.privacy_policy_url,
          last_crawled_at: NaiveDateTime.utc_now()
        })
    end
  end

  defp clean_whitespace(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp remove_common_navigation_text(text) do
    # Remove common navigation and boilerplate text
    patterns_to_remove = [
      ~r/(?i)cookie\s+consent.*?accept/s,
      ~r/(?i)skip\s+to\s+main\s+content/,
      ~r/(?i)menu/,
      ~r/(?i)search/,
      ~r/(?i)newsletter/,
      ~r/(?i)follow\s+us/,
      ~r/(?i)back\s+to\s+top/
    ]

    Enum.reduce(patterns_to_remove, text, fn pattern, acc ->
      String.replace(acc, pattern, "")
    end)
    |> clean_whitespace()
  end

  @doc """
  Validates if scraped content contains meaningful TOS/Privacy Policy text.
  """
  def validate_content(content, content_type) do
    case content_type do
      "terms_of_service" -> validate_tos_content(content)
      "privacy_policy" -> validate_privacy_content(content)
      _ -> false
    end
  end

  defp validate_tos_content(content) when is_binary(content) do
    content_lower = String.downcase(content)

    required_keywords = ["terms", "service", "agreement"]
    strong_indicators = ["liability", "warranty", "dispute", "termination", "intellectual property"]

    has_required = Enum.all?(required_keywords, &String.contains?(content_lower, &1))
    has_strong = Enum.any?(strong_indicators, &String.contains?(content_lower, &1))

    has_required and has_strong and String.length(content) > 1000
  end

  defp validate_privacy_content(content) when is_binary(content) do
    content_lower = String.downcase(content)

    required_keywords = ["privacy", "data"]
    strong_indicators = ["personal information", "collect", "share", "cookies", "tracking"]

    has_required = Enum.all?(required_keywords, &String.contains?(content_lower, &1))
    has_strong = Enum.any?(strong_indicators, &String.contains?(content_lower, &1))

    has_required and has_strong and String.length(content) > 500
  end
end
