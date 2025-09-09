defmodule Sod.ContentExtractor do
  @moduledoc """
  Advanced content extraction utilities for finding and processing TOS/Privacy Policy content.

  This module provides:
  - Smart link detection using multiple strategies
  - Content quality analysis
  - Text preprocessing and normalization
  - Language detection
  """

  require Logger

  @doc """
  Extracts all potential legal document links from HTML content.
  Uses multiple detection strategies for better coverage.
  """
  def extract_legal_links(html, base_url) do
    try do
      {:ok, document} = Floki.parse_document(html)

      strategies = [
        &find_by_link_text/2,
        &find_by_url_patterns/2,
        &find_by_footer_links/2,
        &find_by_nav_links/2,
        &find_by_aria_labels/2
      ]

      results = Enum.reduce(strategies, %{tos: [], privacy: []}, fn strategy, acc ->
        strategy_results = strategy.(document, base_url)
        %{
          tos: acc.tos ++ (strategy_results.tos || []),
          privacy: acc.privacy ++ (strategy_results.privacy || [])
        }
      end)

      # Remove duplicates and rank by confidence
      %{
        tos: results.tos |> Enum.uniq() |> rank_links_by_confidence(:tos),
        privacy: results.privacy |> Enum.uniq() |> rank_links_by_confidence(:privacy)
      }
    rescue
      error ->
        Logger.warning("Error extracting legal links: #{inspect(error)}")
        %{tos: [], privacy: []}
    end
  end

  @doc """
  Analyzes content quality and determines if it's suitable for AI analysis.
  """
  def analyze_content_quality(content) when is_binary(content) do
    metrics = %{
      length: String.length(content),
      word_count: count_words(content),
      sentence_count: count_sentences(content),
      paragraph_count: count_paragraphs(content),
      legal_keyword_density: calculate_legal_keyword_density(content),
      readability_score: calculate_readability_score(content),
      has_structure: has_legal_structure?(content),
      language: detect_language(content)
    }

    quality_score = calculate_quality_score(metrics)

    %{
      metrics: metrics,
      quality_score: quality_score,
      is_analyzable: quality_score > 0.6,
      recommendations: generate_recommendations(metrics)
    }
  end

  @doc """
  Preprocesses content for optimal AI analysis.
  """
  def preprocess_content(content) when is_binary(content) do
    content
    |> normalize_whitespace()
    |> remove_boilerplate_text()
    |> fix_encoding_issues()
    |> standardize_legal_terms()
    |> remove_excessive_repetition()
  end

  @doc """
  Detects the type of legal document based on content analysis.
  """
  def detect_document_type(content) when is_binary(content) do
    content_lower = String.downcase(content)

    tos_indicators = [
      {"terms of service", 10}, {"terms and conditions", 10}, {"user agreement", 8},
      {"terms of use", 9}, {"service agreement", 7}, {"acceptable use", 6},
      {"license agreement", 5}, {"end user license", 5}
    ]

    privacy_indicators = [
      {"privacy policy", 10}, {"privacy notice", 8}, {"data protection", 7},
      {"privacy statement", 8}, {"cookie policy", 6}, {"data processing", 5}
    ]

    tos_score = calculate_indicator_score(content_lower, tos_indicators)
    privacy_score = calculate_indicator_score(content_lower, privacy_indicators)

    cond do
      tos_score > privacy_score and tos_score > 15 -> {:terms_of_service, tos_score}
      privacy_score > tos_score and privacy_score > 15 -> {:privacy_policy, privacy_score}
      tos_score > 10 or privacy_score > 10 -> {:legal_document, max(tos_score, privacy_score)}
      true -> {:unknown, 0}
    end
  end

  @doc """
  Extracts structured sections from legal documents.
  """
  def extract_sections(content) when is_binary(content) do
    # Common section patterns in legal documents
    section_patterns = [
      ~r/(?i)(?:^|\n)\s*(?:\d+\.?\s+)?([A-Z][A-Z\s&]+)(?:\n|$)/m,
      ~r/(?i)(?:^|\n)\s*([A-Z][a-z]+(?:\s+[A-Za-z]+)*):?\s*(?:\n|$)/m,
      ~r/(?i)(?:^|\n)\s*(\d+\.\s*[A-Z][a-z]+(?:\s+[A-Za-z]+)*)/m
    ]

    sections = Enum.reduce(section_patterns, [], fn pattern, acc ->
      matches = Regex.scan(pattern, content, capture: :all_but_first)
      formatted_matches = Enum.map(matches, fn [title] -> String.trim(title) end)
      acc ++ formatted_matches
    end)
    |> Enum.uniq()
    |> Enum.filter(&(String.length(&1) > 3 and String.length(&1) < 100))

    # Extract content for each section
    Enum.map(sections, fn section_title ->
      section_content = extract_section_content(content, section_title)
      %{
        title: section_title,
        content: section_content,
        word_count: count_words(section_content)
      }
    end)
    |> Enum.filter(&(&1.word_count > 10))
  end

  # Private helper functions

  defp find_by_link_text(document, base_url) do
    tos_texts = [
      "terms of service", "terms and conditions", "terms of use", "user agreement",
      "terms", "tos", "legal terms", "service terms", "conditions"
    ]

    privacy_texts = [
      "privacy policy", "privacy", "privacy notice", "privacy statement",
      "data protection", "data policy", "cookie policy"
    ]

    links = Floki.find(document, "a")

    tos_links = find_links_by_text(links, tos_texts, base_url)
    privacy_links = find_links_by_text(links, privacy_texts, base_url)

    %{tos: tos_links, privacy: privacy_links}
  end

  defp find_by_url_patterns(document, base_url) do
    tos_patterns = [
      ~r/terms[-_]?of[-_]?service/i, ~r/terms[-_]?and[-_]?conditions/i,
      ~r/user[-_]?agreement/i, ~r/\/terms\//i, ~r/\/tos\//i
    ]

    privacy_patterns = [
      ~r/privacy[-_]?policy/i, ~r/privacy[-_]?notice/i,
      ~r/data[-_]?protection/i, ~r/\/privacy\//i
    ]

    links = Floki.find(document, "a") |> Floki.attribute("href")

    tos_links = find_links_by_patterns(links, tos_patterns, base_url)
    privacy_links = find_links_by_patterns(links, privacy_patterns, base_url)

    %{tos: tos_links, privacy: privacy_links}
  end

  defp find_by_footer_links(document, base_url) do
    footer_selectors = ["footer", ".footer", "#footer", ".site-footer", ".page-footer"]

    footer_links = Enum.flat_map(footer_selectors, fn selector ->
      Floki.find(document, "#{selector} a") |> Floki.attribute("href")
    end)

    find_legal_links_in_list(footer_links, base_url)
  end

  defp find_by_nav_links(document, base_url) do
    nav_selectors = ["nav", ".nav", ".navigation", ".main-nav", ".site-nav"]

    nav_links = Enum.flat_map(nav_selectors, fn selector ->
      Floki.find(document, "#{selector} a") |> Floki.attribute("href")
    end)

    find_legal_links_in_list(nav_links, base_url)
  end

  defp find_by_aria_labels(document, base_url) do
    aria_selectors = [
      "a[aria-label*=\"terms\"]", "a[aria-label*=\"privacy\"]",
      "a[title*=\"terms\"]", "a[title*=\"privacy\"]"
    ]

    links = Enum.flat_map(aria_selectors, fn selector ->
      Floki.find(document, selector) |> Floki.attribute("href")
    end)

    find_legal_links_in_list(links, base_url)
  end

  defp find_links_by_text(links, target_texts, base_url) do
    Enum.filter(links, fn link ->
      link_text = Floki.text(link) |> String.downcase() |> String.trim()
      Enum.any?(target_texts, &String.contains?(link_text, &1))
    end)
    |> Floki.attribute("href")
    |> Enum.map(&resolve_url(&1, base_url))
    |> Enum.reject(&is_nil/1)
  end

  defp find_links_by_patterns(links, patterns, base_url) do
    Enum.filter(links, fn href ->
      href && Enum.any?(patterns, &Regex.match?(&1, href))
    end)
    |> Enum.map(&resolve_url(&1, base_url))
    |> Enum.reject(&is_nil/1)
  end

  defp find_legal_links_in_list(links, base_url) do
    legal_indicators = [
      "terms", "privacy", "legal", "policy", "conditions", "agreement"
    ]

    filtered_links = Enum.filter(links, fn href ->
      href && Enum.any?(legal_indicators, &String.contains?(String.downcase(href), &1))
    end)
    |> Enum.map(&resolve_url(&1, base_url))
    |> Enum.reject(&is_nil/1)

    # Separate into TOS and Privacy
    tos_links = Enum.filter(filtered_links, &looks_like_tos_url?/1)
    privacy_links = Enum.filter(filtered_links, &looks_like_privacy_url?/1)

    %{tos: tos_links, privacy: privacy_links}
  end

  defp looks_like_tos_url?(url) do
    url_lower = String.downcase(url)
    Enum.any?(["terms", "conditions", "agreement", "tos"], &String.contains?(url_lower, &1))
  end

  defp looks_like_privacy_url?(url) do
    url_lower = String.downcase(url)
    Enum.any?(["privacy", "data-protection"], &String.contains?(url_lower, &1))
  end

  defp rank_links_by_confidence(links, type) do
    Enum.map(links, fn url ->
      confidence = calculate_link_confidence(url, type)
      {url, confidence}
    end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.map(&elem(&1, 0))
  end

  defp calculate_link_confidence(url, type) do
    url_lower = String.downcase(url)

    base_score = case type do
      :tos ->
        cond do
          String.contains?(url_lower, "terms-of-service") -> 10
          String.contains?(url_lower, "terms") -> 8
          String.contains?(url_lower, "conditions") -> 7
          String.contains?(url_lower, "agreement") -> 6
          true -> 3
        end
      :privacy ->
        cond do
          String.contains?(url_lower, "privacy-policy") -> 10
          String.contains?(url_lower, "privacy") -> 8
          String.contains?(url_lower, "data-protection") -> 7
          true -> 3
        end
    end

    # Boost score for common path patterns
    path_boost = cond do
      String.contains?(url_lower, "/legal/") -> 2
      String.ends_with?(url_lower, "/#{type}") -> 3
      true -> 0
    end

    base_score + path_boost
  end

  defp resolve_url(relative_url, base_url) do
    # Similar to the one in Scraper module
    cond do
      is_nil(relative_url) -> nil
      String.starts_with?(relative_url, "http") -> relative_url
      String.starts_with?(relative_url, "//") -> "https:#{relative_url}"
      String.starts_with?(relative_url, "/") ->
        %URI{scheme: scheme, host: host} = URI.parse(base_url)
        "#{scheme}://#{host}#{relative_url}"
      String.starts_with?(relative_url, "#") -> nil
      String.contains?(relative_url, "javascript:") -> nil
      String.contains?(relative_url, "mailto:") -> nil
      true ->
        base_uri = URI.parse(base_url)
        URI.to_string(%{base_uri | path: Path.join(base_uri.path || "/", relative_url)})
    end
  rescue
    _ -> nil
  end

  defp count_words(text), do: String.split(text) |> length()
  defp count_sentences(text), do: String.split(text, ~r/[.!?]+/) |> length()
  defp count_paragraphs(text), do: String.split(text, ~r/\n\s*\n/) |> length()

  defp calculate_legal_keyword_density(content) do
    legal_keywords = [
      "agreement", "liability", "warranty", "terms", "conditions", "privacy",
      "data", "personal", "information", "collect", "share", "cookies",
      "tracking", "consent", "rights", "policy", "legal", "copyright",
      "intellectual property", "dispute", "termination", "modification"
    ]

    content_lower = String.downcase(content)
    word_count = count_words(content)

    if word_count == 0 do
      0.0
    else
      keyword_matches = Enum.count(legal_keywords, &String.contains?(content_lower, &1))
      keyword_matches / word_count * 100
    end
  end

  defp calculate_readability_score(content) do
    # Simple readability metric based on average word and sentence length
    words = String.split(content)
    sentences = String.split(content, ~r/[.!?]+/)

    if length(sentences) == 0 or length(words) == 0 do
      0.0
    else
      avg_words_per_sentence = length(words) / length(sentences)
      avg_chars_per_word = String.length(content) / length(words)

      # Higher scores for more readable content (shorter sentences, shorter words)
      readability = 100 - (avg_words_per_sentence * 2) - (avg_chars_per_word * 5)
      max(0.0, min(100.0, readability))
    end
  end

  defp has_legal_structure?(content) do
    # Check for common legal document structure indicators
    structure_indicators = [
      ~r/(?i)\d+\.\s*[A-Z]/,  # Numbered sections
      ~r/(?i)^[A-Z\s]+$/m,     # ALL CAPS headings
      ~r/(?i)whereas/,         # Legal preamble
      ~r/(?i)section\s+\d+/,   # Section references
      ~r/(?i)article\s+\d+/,   # Article references
    ]

    indicator_count = Enum.count(structure_indicators, &Regex.match?(&1, content))
    indicator_count >= 2
  end

  defp detect_language(content) do
    # Simple language detection based on common words
    # This is a basic implementation - consider using a proper language detection library
    english_indicators = ["the", "and", "of", "to", "a", "in", "is", "you", "that", "it"]
    spanish_indicators = ["el", "de", "que", "y", "la", "en", "un", "es", "se", "no"]
    french_indicators = ["le", "de", "et", "à", "un", "il", "être", "et", "en", "avoir"]

    content_words = content |> String.downcase() |> String.split() |> Enum.take(100)

    english_score = Enum.count(content_words, &(&1 in english_indicators))
    spanish_score = Enum.count(content_words, &(&1 in spanish_indicators))
    french_score = Enum.count(content_words, &(&1 in french_indicators))

    cond do
      english_score >= spanish_score and english_score >= french_score -> "en"
      spanish_score >= french_score -> "es"
      french_score > 0 -> "fr"
      true -> "unknown"
    end
  end

  defp calculate_quality_score(metrics) do
    scores = [
      # Length score (sweet spot around 2000-10000 words)
      case metrics.word_count do
        count when count < 100 -> 0.1
        count when count < 500 -> 0.4
        count when count < 2000 -> 0.8
        count when count < 10000 -> 1.0
        count when count < 20000 -> 0.9
        _ -> 0.7
      end,

      # Legal keyword density score
      case metrics.legal_keyword_density do
        density when density < 0.5 -> 0.2
        density when density < 1.0 -> 0.5
        density when density < 3.0 -> 1.0
        density when density < 5.0 -> 0.9
        _ -> 0.7
      end,

      # Structure score
      (if metrics.has_structure, do: 1.0, else: 0.3),
      # Language score
      (if metrics.language == "en", do: 1.0, else: 0.8),
    ]

    Enum.sum(scores) / length(scores)
  end

  defp generate_recommendations(metrics) do
    recommendations = []

    recommendations = if metrics.word_count < 500 do
      ["Content appears too short for comprehensive analysis" | recommendations]
    else
      recommendations
    end

    recommendations = if metrics.legal_keyword_density < 1.0 do
      ["Low legal keyword density - may not be a legal document" | recommendations]
    else
      recommendations
    end

    recommendations = unless metrics.has_structure do
      ["Document lacks clear legal structure" | recommendations]
    else
      recommendations
    end

    recommendations = if metrics.language != "en" do
      ["Non-English content may result in lower analysis accuracy" | recommendations]
    else
      recommendations
    end

    if length(recommendations) == 0 do
      ["Content appears suitable for analysis"]
    else
      recommendations
    end
  end

  defp calculate_indicator_score(content, indicators) do
    Enum.reduce(indicators, 0, fn {term, weight}, acc ->
      if String.contains?(content, term) do
        acc + weight
      else
        acc
      end
    end)
  end

  defp extract_section_content(content, section_title) do
    # This is a simplified version - you might want to implement more sophisticated section extraction
    case String.split(content, section_title, parts: 2) do
      [_, rest] ->
        # Take content until the next major section or end
        case Regex.run(~r/^(.{0,2000}?)(?:\n\s*(?:[A-Z][A-Z\s]+|SECTION|ARTICLE|\d+\.)\s*\n|$)/s, rest) do
          [_, section_content] -> String.trim(section_content)
          _ -> String.slice(rest, 0, 1000)
        end
      _ -> ""
    end
  end

  defp normalize_whitespace(content) do
    content
    |> String.replace(~r/\r\n|\r/, "\n")
    |> String.replace(~r/[ \t]+/, " ")
    |> String.replace(~r/\n[ \t]+/, "\n")
    |> String.replace(~r/\n{3,}/, "\n\n")
  end

  defp remove_boilerplate_text(content) do
    # Remove common boilerplate text patterns
    patterns = [
      ~r/(?i)this page uses cookies.*?(?=\n\n|\.|$)/s,
      ~r/(?i)accept all cookies.*?(?=\n\n|\.|$)/s,
      ~r/(?i)cookie banner.*?(?=\n\n|\.|$)/s,
      ~r/(?i)skip to main content/i,
      ~r/(?i)back to top/i
    ]

    Enum.reduce(patterns, content, &String.replace(&2, &1, ""))
  end

  defp fix_encoding_issues(content) do
    content
    |> String.replace(~r/â€™/, "'")
    |> String.replace(~r/â€œ/, "\"")

    |> String.replace(~r/â€\x9D/, "\"")
    |> String.replace(~r/â€"/, "–")
    |> String.replace(~r/â€"/, "—")
  end

  defp standardize_legal_terms(content) do
    # Standardize common legal term variations
    standardizations = [
      {~r/\bterms of service\b/i, "Terms of Service"},
      {~r/\bprivacy policy\b/i, "Privacy Policy"},
      {~r/\bterms and conditions\b/i, "Terms and Conditions"},
      {~r/\bpersonal data\b/i, "Personal Data"},
      {~r/\bpersonal information\b/i, "Personal Information"}
    ]

    Enum.reduce(standardizations, content, fn {pattern, replacement}, acc ->
      String.replace(acc, pattern, replacement)
    end)
  end

  defp remove_excessive_repetition(content) do
    # Remove lines that are repeated more than 3 times
    lines = String.split(content, "\n")
    line_counts = Enum.frequencies(lines)

    filtered_lines = Enum.reduce(lines, [], fn line, acc ->
      if Map.get(line_counts, line, 1) <= 3 or String.trim(line) == "" do
        [line | acc]
      else
        acc
      end
    end)

    filtered_lines |> Enum.reverse() |> Enum.join("\n")
  end
end
