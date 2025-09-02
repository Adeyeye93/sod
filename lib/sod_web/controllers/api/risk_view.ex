# defmodule SodWeb.API.RiskView do
#   use SodWeb, :view

#   def render("analysis.json", %{analysis: analysis}) do
#     %{
#       overall_risk_score: analysis.overall_risk_score,
#       risk_level: analysis.risk_level,
#       risk_color: analysis.risk_color,
#       scores: %{
#         data_sharing: analysis.data_sharing_score,
#         data_collection: analysis.data_collection_score,
#         personalization_tracking: analysis.personalization_tracking_score,
#         data_retention: analysis.data_retention_score,
#         employee_access: analysis.employee_access_score,
#         cross_border_transfer: analysis.cross_border_transfer_score,
#         security_practices: analysis.security_practices_score,
#         ai_concerns: analysis.ai_concerns_score,
#         communication: analysis.communication_score,
#         miscellaneous_risks: analysis.miscellaneous_risks_score
#       },
#       detected_practices: analysis.detected_practices,
#       analysis_date: analysis.analysis_date,
#       ai_model_version: analysis.ai_model_version,
#       confidence_score: analysis.confidence_score,
#       recommendation_summary: analysis.recommendation_summary
#     }
#   end

#   def render("personalized_analysis.json", %{analysis: analysis, source: source}) do
#     %{
#       source: source,
#       personalized_risk_score: analysis.personalized_risk_score,
#       violated_preferences: analysis.violated_preferences,
#       personalized_warnings: analysis.personalized_warnings,
#       user_recommendation: analysis.user_recommendation,
#       base_analysis: render_one(analysis.base_analysis, __MODULE__, "analysis.json", as: :analysis)
#     }
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
#       inserted_at: alert.inserted_at,
#       updated_at: alert.updated_at,
#       site: render_site(alert.site)
#     }
#   end

#   def render("alerts.json", %{alerts: alerts}) do
#     %{
#       alerts: render_many(alerts, __MODULE__, "alert.json", as: :alert)
#     }
#   end

#   def render("risk_summary.json", %{visit_statistics: visit_stats, alert_statistics: alert_stats, high_risk_sites: sites}) do
#     %{
#       visit_statistics: visit_stats,
#       alert_statistics: alert_stats,
#       high_risk_sites: Enum.map(sites, &render_site/1)
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
# end
