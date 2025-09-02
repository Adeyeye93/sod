# defmodule SodWeb.API.ExtensionView do
#   use SodWeb, :view

#   def render("site.json", %{site: site}) do
#     %{
#       id: site.id,
#       domain: site.domain,
#       name: site.name
#     }
#   end

#   def render("analysis.json", %{type: type, source: source, analysis: analysis}) when type == :basic do
#     %{
#       type: "basic",
#       source: source,
#       analysis: %{
#         overall_risk_score: analysis.overall_risk_score,
#         risk_level: analysis.risk_level,
#         risk_color: analysis.risk_color,
#         scores: %{
#           data_sharing: analysis.data_sharing_score,
#           data_collection: analysis.data_collection_score,
#           personalization_tracking: analysis.personalization_tracking_score,
#           data_retention: analysis.data_retention_score,
#           employee_access: analysis.employee_access_score,
#           cross_border_transfer: analysis.cross_border_transfer_score,
#           security_practices: analysis.security_practices_score,
#           ai_concerns: analysis.ai_concerns_score,
#           communication: analysis.communication_score,
#           miscellaneous_risks: analysis.miscellaneous_risks_score
#         },
#         detected_practices: analysis.detected_practices,
#         recommendation_summary: analysis.recommendation_summary
#       }
#     }
#   end

#   def render("analysis.json", %{type: type, source: source, analysis: analysis}) when type == :personalized do
#     %{
#       type: "personalized",
#       source: source,
#       analysis: %{
#         personalized_risk_score: analysis.personalized_risk_score,
#         violated_preferences: analysis.violated_preferences,
#         personalized_warnings: analysis.personalized_warnings,
#         user_recommendation: analysis.user_recommendation,
#         base_analysis: render("analysis.json", %{type: :basic, source: source, analysis: analysis.base_analysis}).analysis
#       }
#     }
#   end

#   def render("preferences.json", %{preferences: preferences}) do
#     # Convert struct to map and remove metadata fields
#     preferences
#     |> Map.from_struct()
#     |> Map.drop([:__meta__, :user, :user_id])
#   end

#   def render("alert.json", %{alert: alert}) do
#     %{
#       id: alert.id,
#       alert_type: alert.alert_type,
#       risk_score: alert.risk_score,
#       violated_preferences: alert.violated_preferences,
#       message: alert.message,
#       is_read: alert.is_read,
#       action_taken: alert.action_taken,
#       site: render_site(alert.site),
#       inserted_at: alert.inserted_at
#     }
#   end

#   def render("alerts.json", %{alerts: alerts}) do
#     %{
#       alerts: Enum.map(alerts, &render("alert.json", %{alert: &1}))
#     }
#   end

#   def render("error.json", %{error: error}) do
#     %{
#       error: error_message(error)
#     }
#   end

#   # Private helpers

#   defp render_site(nil), do: nil
#   defp render_site(site) do
#     %{
#       id: site.id,
#       domain: site.domain,
#       name: site.name
#     }
#   end

#   defp error_message({:error, :invalid_session}), do: "Invalid or expired session"
#   defp error_message({:error, :not_found}), do: "Resource not found"
#   defp error_message({:error, %Ecto.Changeset{} = changeset}) do
#     Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
#   end
#   defp error_message(error) when is_binary(error), do: error
#   defp error_message(_), do: "An unexpected error occurred"
# end
