defmodule Sod.BackgroundJobs.AiAnalyzer do
  use GenServer
  alias Sod.Sites
  alias Sod.RiskAnalyzer
  # alias Sod.AiCache

  @analysis_interval :timer.hours(12)  # Analyze every 12 hours

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    schedule_analysis()
    {:ok, %{}}
  end

  def handle_info(:analyze_sites, state) do
    analyze_pending_sites()
    schedule_analysis()
    {:noreply, state}
  end

  def handle_call({:analyze_site, site_id}, _from, state) do
    result = analyze_single_site(site_id)
    {:reply, result, state}
  end

  def analyze_site_now(site_id) do
    GenServer.call(__MODULE__, {:analyze_site, site_id}, 60_000)
  end

  defp schedule_analysis do
    Process.send_after(self(), :analyze_sites, @analysis_interval)
  end

  defp analyze_pending_sites do
    # Get sites that need analysis
    sites_to_analyze = get_sites_needing_analysis()

    # Batch process with rate limiting
    sites_to_analyze
    |> Enum.chunk_every(5)  # Process 5 at a time
    |> Enum.each(fn batch ->
      analyze_site_batch(batch)
      Process.sleep(1000)  # Rate limiting
    end)
  end

  defp get_sites_needing_analysis do
    # Get sites that don't have recent analysis or have stale cache
    threshold = NaiveDateTime.utc_now() |> NaiveDateTime.add(-24 * 3600, :second)

    Sites.list_sites()
    |> Enum.filter(fn site ->
      case Sod.Analytics.get_site_risk_analysis(site.id) do
        nil -> true  # No analysis exists
        analysis -> NaiveDateTime.compare(analysis.analysis_date, threshold) == :lt  # Analysis is old
      end
    end)
  end

  defp analyze_site_batch(sites) do
    RiskAnalyzer.bulk_analyze_sites(sites, concurrency: 3)
  end

  defp analyze_single_site(site_id) do
    case Sites.get_site!(site_id) do
      nil -> {:error, :site_not_found}

      site ->
        # This would fetch actual TOS content
        mock_content = "TOS content for #{site.domain}"
        RiskAnalyzer.analyze_tos_content(mock_content, "terms_of_service", site.id)

    end
  end
end
