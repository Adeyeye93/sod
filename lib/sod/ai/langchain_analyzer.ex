defmodule Sod.Ai.LangchainAnalyzer do
  @moduledoc """
  LangChain integration for TOS and Privacy Policy analysis.
  """

  alias Sod.AiCache
  alias Sod.Preference.UserPreference

  @doc """
  Analyzes TOS content using AI with intelligent caching.
  """
  def analyze_tos_content(content, content_type, site_id, options \\ []) do
    content_hash = generate_content_hash(content)

    # Check cache first
    case AiCache.get_cached_analysis(content_hash, content_type) do
      nil ->
        # Not in cache, analyze with AI
        perform_ai_analysis(content, content_type, site_id, content_hash, options)

      cached_result ->
        # Cache hit! Return cached result
        {:ok, :cached, cached_result}
    end
  end

  @doc """
  Analyzes content for specific user preferences.
  """
  def analyze_for_user(content, content_type, %UserPreference{} = user_preferences, site_id) do
    # Get base analysis (cached or fresh)
    case analyze_tos_content(content, content_type, site_id) do
      {:ok, source, analysis_cache} ->
        # Personalize the analysis based on user preferences
        personalized_analysis = personalize_analysis(analysis_cache, user_preferences)

        # Save user-specific analysis history
        save_user_analysis_history(user_preferences.user_id, site_id, analysis_cache, personalized_analysis)

        {:ok, source, personalized_analysis}

      error -> error
    end
  end

  defp perform_ai_analysis(content, content_type, site_id, content_hash, options) do
    start_time = System.monotonic_time(:millisecond)
    ai_model = Keyword.get(options, :model, "gpt-4")

    # Prepare the AI prompt
    prompt = build_analysis_prompt(content, content_type)

    # Call AI service (this would be your actual LangChain integration)
    case call_ai_service(prompt, ai_model) do
      {:ok, ai_response} ->
        end_time = System.monotonic_time(:millisecond)
        analysis_duration = end_time - start_time

        # Process AI response into structured format
        structured_analysis = process_ai_response(ai_response)

        # Extract and save clauses to library
        extract_and_save_clauses(structured_analysis[:detected_clauses], site_id, ai_model)

        # Save to cache
        cache_attrs = Map.merge(structured_analysis, %{
          site_id: site_id,
          content_hash: content_hash,
          content_type: content_type,
          content_length: String.length(content),
          ai_model_used: ai_model,
          analysis_version: "1.0.0",
          tokens_used: calculate_tokens_used(content, ai_response),
          analysis_duration_ms: analysis_duration,
          analyzed_at: NaiveDateTime.utc_now()
        })

        case AiCache.create_cached_analysis(cache_attrs) do
          {:ok, cached_analysis} -> {:ok, :fresh, cached_analysis}
          error -> error
        end
      #TODO: Handle specific error cases from AI service
      # {, reason} -> {:error, reason}
    end
  end

  defp build_analysis_prompt(content, content_type) do
    """
    You are a privacy expert analyzing #{content_type}. Analyze the following document and provide a detailed risk assessment.

    Focus on these key areas:
    1. Data Sharing & Selling practices
    2. Data Collection methods
    3. Personalization & Tracking
    4. Data Retention policies
    5. Employee Access rights
    6. Cross-Border Data Transfer
    7. Security Practices
    8. AI-Specific Concerns
    9. Communication preferences
    10. Miscellaneous risky practices

    For each risky clause found, provide:
    - Exact quote from the document
    - Risk level (low/medium/high/critical)
    - Explanation of why it's risky
    - User impact description
    - Mitigation advice

    Document to analyze:
    #{content}

    Respond in JSON format with this structure:
    {
      "overall_risk_score": 0-100,
      "confidence_score": 0.0-1.0,
      "detected_clauses": [
        {
          "clause_text": "exact quote",
          "section": "section name",
          "position": line_number,
          "risk_level": "high",
          "risk_category": "data_sharing",
          "explanation": "why risky",
          "user_impact": "how it affects users",
          "mitigation_advice": "what users can do"
        }
      ],
      "risk_breakdown": {
        "data_sharing": 0-100,
        "data_collection": 0-100,
        // ... other categories
      },
      "recommendation_summary": "Overall recommendation and key points to consider"
    }
    """
  end

  defp call_ai_service(_prompt, _model) do
    # This is where you'd integrate with your actual AI service
    # For now, returning a mock response structure

    # Example using HTTPoison to call OpenAI API:
    # headers = [
    #   {"Authorization", "Bearer #{api_key}"},
    #   {"Content-Type", "application/json"}
    # ]
    #
    # body = Jason.encode!(%{
    #   model: model,
    #   messages: [%{role: "user", content: prompt}],
    #   temperature: 0.1,
    #   max_tokens: 4000
    # })
    #
    # case HTTPoison.post("https://api.openai.com/v1/chat/completions", body, headers) do
    #   {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
    #     case Jason.decode(response_body) do
    #       {:ok, %{"choices" => [%{"message" => %{"content" => content}}]}} ->
    #         case Jason.decode(content) do
    #           {:ok, parsed_response} -> {:ok, parsed_response}
    #           error -> {:error, "Failed to parse AI response"}
    #         end
    #       error -> {:error, "Invalid API response format"}
    #     end
    #   {:ok, response} -> {:error, "API error: #{response.status_code}"}
    #   {:error, error} -> {:error, "Request failed: #{inspect(error)}"}
    # end

    # Mock response for now
    {:ok, %{
      "overall_risk_score" => 75,
      "confidence_score" => 0.87,
      "detected_clauses" => [
        %{
          "clause_text" => "We may share your personal information with third parties for marketing purposes",
          "section" => "Information Sharing",
          "position" => 45,
          "risk_level" => "high",
          "risk_category" => "data_sharing",
          "explanation" => "Allows unlimited sharing of personal data with third parties for marketing",
          "user_impact" => "Your personal information could be sold to marketers, leading to spam and privacy loss",
          "mitigation_advice" => "Consider opting out of marketing communications and data sharing if possible"
        }
      ],
      "risk_breakdown" => %{
        "data_sharing" => 85,
        "data_collection" => 60,
        "personalization_tracking" => 70,
        "data_retention" => 40,
        "employee_access" => 30,
        "cross_border_transfer" => 50,
        "security_practices" => 60,
        "ai_concerns" => 20,
        "communication" => 80,
        "miscellaneous_risks" => 45
      },
      "recommendation_summary" => "This service has significant privacy risks, particularly around data sharing and marketing communications. Users should carefully review opt-out options."
    }}
  end

  defp process_ai_response(ai_response) do
    %{
      risk_analysis: ai_response["risk_breakdown"],
      detected_clauses: ai_response["detected_clauses"],
      risk_explanations: build_risk_explanations(ai_response["detected_clauses"]),
      recommendation_summary: ai_response["recommendation_summary"],
      confidence_score: ai_response["confidence_score"]
    }
  end

  defp build_risk_explanations(detected_clauses) do
    detected_clauses
    |> Enum.group_by(fn clause -> clause["risk_category"] end)
    |> Enum.map(fn {category, clauses} ->
      explanations = Enum.map(clauses, fn clause -> clause["explanation"] end)
      {category, explanations}
    end)
    |> Enum.into(%{})
  end

  defp extract_and_save_clauses(detected_clauses, _site_id, ai_model) do
    Enum.each(detected_clauses, fn clause ->
      clause_attrs = %{
        clause_text: clause["clause_text"],
        clause_summary: clause["explanation"],
        risk_category: clause["risk_category"],
        risk_level: clause["risk_level"],
        risk_score: risk_level_to_score(clause["risk_level"]),
        explanation: clause["explanation"],
        user_impact: clause["user_impact"],
        mitigation_advice: clause["mitigation_advice"],
        clause_type: clause["risk_category"],
        keywords: extract_keywords(clause["clause_text"]),
        last_seen_at: NaiveDateTime.utc_now(),
        created_by_ai_model: ai_model
      }

      AiCache.upsert_clause(clause_attrs)
    end)
  end

  defp personalize_analysis(analysis_cache, user_preferences) do
    # Calculate personalized risk score based on user preferences
    base_score = analysis_cache.risk_analysis["overall_risk_score"] || 0

    # Check which user preferences are violated
    violated_preferences = check_preference_violations(analysis_cache, user_preferences)

    # Adjust risk score based on user's tolerance
    personalized_score = calculate_personalized_risk_score(base_score, violated_preferences)

    # Generate personalized warnings
    personalized_warnings = generate_personalized_warnings(analysis_cache, violated_preferences)

    # Generate recommendation
    user_recommendation = generate_user_recommendation(personalized_score, violated_preferences)

    %{
      base_analysis: analysis_cache,
      personalized_risk_score: personalized_score,
      violated_preferences: violated_preferences,
      personalized_warnings: personalized_warnings,
      user_recommendation: user_recommendation
    }
  end

  defp check_preference_violations(analysis_cache, user_preferences) do
    detected_practices = analysis_cache.detected_clauses || []

    # Map detected clauses to preference violations
    Enum.reduce(detected_practices, [], fn clause, violations ->
      case clause["risk_category"] do
        "data_sharing" ->
          check_data_sharing_violations(clause, user_preferences, violations)
        "data_collection" ->
          check_data_collection_violations(clause, user_preferences, violations)
        "personalization_tracking" ->
          check_tracking_violations(clause, user_preferences, violations)
        "data_retention" ->
          check_retention_violations(clause, user_preferences, violations)
        "employee_access" ->
          check_employee_access_violations(clause, user_preferences, violations)
        "cross_border_transfer" ->
          check_transfer_violations(clause, user_preferences, violations)
        "security_practices" ->
          check_security_violations(clause, user_preferences, violations)
        "ai_concerns" ->
          check_ai_violations(clause, user_preferences, violations)
        "communication" ->
          check_communication_violations(clause, user_preferences, violations)
        _ ->
          violations
      end
    end)
    |> Enum.uniq()
  end

  defp check_data_sharing_violations(clause, preferences, violations) do
    clause_text = String.downcase(clause["clause_text"])
    new_violations = []

    new_violations = if String.contains?(clause_text, ["sell", "selling", "monetize"]) and
                        preferences.allow_data_selling == false do
      ["allow_data_selling" | new_violations]
    else
      new_violations
    end

    new_violations = if String.contains?(clause_text, ["third party", "partners", "affiliates"]) and
                        preferences.allow_third_party_sharing == false do
      ["allow_third_party_sharing" | new_violations]
    else
      new_violations
    end

    new_violations = if String.contains?(clause_text, ["marketing", "advertising"]) and
                        preferences.allow_marketing_data_sharing == false do
      ["allow_marketing_data_sharing" | new_violations]
    else
      new_violations
    end

    violations ++ new_violations
  end

  defp check_data_collection_violations(clause, preferences, violations) do
    clause_text = String.downcase(clause["clause_text"])
    new_violations = []

    new_violations = if String.contains?(clause_text, ["location", "gps", "precise location"]) and
                        preferences.allow_precise_location == false do
      ["allow_precise_location" | new_violations]
    else
      new_violations
    end

    new_violations = if String.contains?(clause_text, ["contacts", "address book"]) and
                        preferences.allow_contacts_access == false do
      ["allow_contacts_access" | new_violations]
    else
      new_violations
    end

    new_violations = if String.contains?(clause_text, ["camera", "photos", "images"]) and
                        preferences.allow_camera_access == false do
      ["allow_camera_access" | new_violations]
    else
      new_violations
    end

    new_violations = if String.contains?(clause_text, ["microphone", "audio", "voice"]) and
                        preferences.allow_microphone_access == false do
      ["allow_microphone_access" | new_violations]
    else
      new_violations
    end

    new_violations = if String.contains?(clause_text, ["clipboard", "copy", "paste"]) and
                        preferences.allow_clipboard_reading == false do
      ["allow_clipboard_reading" | new_violations]
    else
      new_violations
    end

    new_violations = if String.contains?(clause_text, ["keyboard", "keylogging", "input"]) and
                        preferences.allow_keyboard_input_reading == false do
      ["allow_keyboard_input_reading" | new_violations]
    else
      new_violations
    end

    violations ++ new_violations
  end

  defp check_tracking_violations(clause, preferences, violations) do
    clause_text = String.downcase(clause["clause_text"])
    new_violations = []

    new_violations = if String.contains?(clause_text, ["cross-site", "cross site", "tracking across"]) and
                        preferences.allow_cross_site_tracking == false do
      ["allow_cross_site_tracking" | new_violations]
    else
      new_violations
    end

    new_violations = if String.contains?(clause_text, ["behavioral tracking", "behavior tracking", "ai training"]) and
                        preferences.allow_behavioral_tracking_ai == false do
      ["allow_behavioral_tracking_ai" | new_violations]
    else
      new_violations
    end

    violations ++ new_violations
  end

  defp check_retention_violations(clause, preferences, violations) do
    clause_text = String.downcase(clause["clause_text"])
    new_violations = []

    new_violations = if String.contains?(clause_text, ["indefinitely", "indefinite", "permanent"]) and
                        preferences.allow_indefinite_retention == false do
      ["allow_indefinite_retention" | new_violations]
    else
      new_violations
    end

    new_violations = if String.contains?(clause_text, ["after deletion", "after account deletion"]) and
                        preferences.allow_retention_after_deletion == false do
      ["allow_retention_after_deletion" | new_violations]
    else
      new_violations
    end

    violations ++ new_violations
  end

  defp check_employee_access_violations(clause, preferences, violations) do
    clause_text = String.downcase(clause["clause_text"])
    new_violations = []

    new_violations = if String.contains?(clause_text, ["employee", "staff", "personnel"]) and
                        preferences.allow_employee_data_access == false do
      ["allow_employee_data_access" | new_violations]
    else
      new_violations
    end

    new_violations = if String.contains?(clause_text, ["ai training", "machine learning", "model training"]) and
                        preferences.allow_ai_training_on_data == false do
      ["allow_ai_training_on_data" | new_violations]
    else
      new_violations
    end

    violations ++ new_violations
  end

  defp check_transfer_violations(clause, preferences, violations) do
    clause_text = String.downcase(clause["clause_text"])
    new_violations = []

    new_violations = if String.contains?(clause_text, ["international", "overseas", "other countries"]) and
                        preferences.allow_international_transfer == false do
      ["allow_international_transfer" | new_violations]
    else
      new_violations
    end

    violations ++ new_violations
  end

  defp check_security_violations(clause, preferences, violations) do
    clause_text = String.downcase(clause["clause_text"])
    new_violations = []

    new_violations = if String.contains?(clause_text, ["weak encryption", "no encryption", "unencrypted"]) and
                        (preferences.allow_weak_encryption_at_rest == false or
                         preferences.allow_no_encryption_in_transit == false) do
      ["allow_weak_encryption_at_rest", "allow_no_encryption_in_transit"] ++ new_violations
    else
      new_violations
    end

    violations ++ new_violations
  end

  defp check_ai_violations(clause, preferences, violations) do
    clause_text = String.downcase(clause["clause_text"])
    new_violations = []

    new_violations = if String.contains?(clause_text, ["ai analysis", "conversation analysis"]) and
                        preferences.allow_ai_conversation_analysis == false do
      ["allow_ai_conversation_analysis" | new_violations]
    else
      new_violations
    end

    violations ++ new_violations
  end

  defp check_communication_violations(clause, preferences, violations) do
    clause_text = String.downcase(clause["clause_text"])
    new_violations = []

    new_violations = if String.contains?(clause_text, ["robocall", "automated call", "auto-dial"]) and
                        preferences.allow_robocalls == false do
      ["allow_robocalls" | new_violations]
    else
      new_violations
    end

    new_violations = if String.contains?(clause_text, ["sms", "text message", "marketing text"]) and
                        preferences.allow_sms_marketing == false do
      ["allow_sms_marketing" | new_violations]
    else
      new_violations
    end

    violations ++ new_violations
  end

  defp calculate_personalized_risk_score(base_score, violated_preferences) do
    # Increase risk score based on number of preference violations
    violation_penalty = length(violated_preferences) * 5
    min(100, base_score + violation_penalty)
  end

  defp generate_personalized_warnings(_analysis_cache, violated_preferences) do
    Enum.map(violated_preferences, fn preference ->
      %{
        preference: preference,
        warning: get_preference_warning(preference),
        severity: get_preference_severity(preference)
      }
    end)
  end

  defp get_preference_warning(preference) do
    case preference do
      "allow_data_selling" -> "This site may sell your personal data to third parties"
      "allow_third_party_sharing" -> "Your data may be shared with unknown third parties"
      "allow_marketing_data_sharing" -> "Your information may be used for targeted marketing"
      "allow_precise_location" -> "This site may track your exact location"
      "allow_contacts_access" -> "This site may access your contact list"
      "allow_camera_access" -> "This site may access your camera"
      "allow_microphone_access" -> "This site may access your microphone"
      "allow_clipboard_reading" -> "This site may read your clipboard data"
      "allow_keyboard_input_reading" -> "This site may log your keyboard inputs"
      "allow_cross_site_tracking" -> "This site may track you across other websites"
      "allow_indefinite_retention" -> "Your data may be kept indefinitely"
      "allow_retention_after_deletion" -> "Your data may be kept even after account deletion"
      "allow_employee_data_access" -> "Employees may access your private data"
      "allow_ai_training_on_data" -> "Your data may be used to train AI models"
      "allow_international_transfer" -> "Your data may be transferred to other countries"
      "allow_robocalls" -> "You may receive automated marketing calls"
      "allow_sms_marketing" -> "You may receive marketing text messages"
      _ -> "This site has practices that conflict with your privacy preferences"
    end
  end

  defp get_preference_severity(preference) do
    case preference do
      p when p in ["allow_data_selling", "allow_keyboard_input_reading", "allow_clipboard_reading"] -> "critical"
      p when p in ["allow_third_party_sharing", "allow_precise_location", "allow_camera_access", "allow_microphone_access"] -> "high"
      p when p in ["allow_marketing_data_sharing", "allow_cross_site_tracking", "allow_indefinite_retention"] -> "medium"
      _ -> "low"
    end
  end

  defp generate_user_recommendation(personalized_score, violated_preferences) do
    cond do
      personalized_score >= 80 or length(violated_preferences) >= 5 -> "avoid"
      personalized_score >= 60 or length(violated_preferences) >= 3 -> "caution"
      true -> "proceed"
    end
  end

  defp save_user_analysis_history(user_id, site_id, analysis_cache, personalized_analysis) do
    attrs = %{
      user_id: user_id,
      site_id: site_id,
      tos_analysis_cache_id: analysis_cache.id,
      personalized_risk_score: personalized_analysis.personalized_risk_score,
      violated_preferences: personalized_analysis.violated_preferences,
      personalized_warnings: personalized_analysis.personalized_warnings,
      user_recommendation: personalized_analysis.user_recommendation,
      analysis_requested_at: NaiveDateTime.utc_now()
    }

    AiCache.create_user_analysis_history(attrs)
  end

  # Utility functions

  defp generate_content_hash(content) when is_binary(content) do
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end

  defp risk_level_to_score(risk_level) do
    case risk_level do
      "critical" -> 95
      "high" -> 80
      "medium" -> 60
      "low" -> 30
    end
  end

  defp extract_keywords(clause_text) do
    # Simple keyword extraction - you could use more sophisticated NLP here
    clause_text
    |> String.downcase()
    |> String.split()
    |> Enum.filter(fn word -> String.length(word) > 3 end)
    |> Enum.take(10)
  end

  # defp calculate_tokens_used(input_content, _ai_response) do
  #   # Rough estimate - you'd want to use actual tokenizer for precise counting
  #   input_tokens = String.length(input_content) / 4  # Rough estimate
  #   output_tokens = input_content |> Jason.encode!() |> String.length() / 4
  #   round(input_tokens + output_tokens)
  # end

  defp calculate_tokens_used(input_content, ai_response) do
  # Encode to string form so we can measure
  input_str = Jason.encode!(input_content)
  output_str = Jason.encode!(ai_response)

  input_tokens = String.length(input_str) / 4
  output_tokens = String.length(output_str) / 4

  round(input_tokens + output_tokens)
end

end
