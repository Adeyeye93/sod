defmodule Sod.Sites do
  @moduledoc """
  The Sites context for managing websites and their terms of service.
  """

  import Ecto.Query, warn: false
  alias Sod.Repo
  alias Sod.Sites.{Site, TosVersion}

  @doc """
  Returns the list of sites.
  """
  def list_sites do
    Repo.all(Site)
  end

  
  @doc """
  Gets a single site.
  """
  def get_site!(id), do: Repo.get!(Site, id)

  @doc """
  Gets a site by domain.
  """
  def get_site_by_domain(domain) do
    Repo.get_by(Site, domain: domain)
  end

  @doc """
  Gets or creates a site by domain.
  """
  def get_or_create_site_by_domain(domain) do
    case get_site_by_domain(domain) do
      nil -> create_site(%{domain: domain})
      site -> {:ok, site}
    end
  end

  @doc """
  Creates a site.
  """
  def create_site(attrs \\ %{}) do
    %Site{}
    |> Site.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a site.
  """
  def update_site(%Site{} = site, attrs) do
    site
    |> Site.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a site.
  """
  def delete_site(%Site{} = site) do
    Repo.delete(site)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking site changes.
  """
  def change_site(%Site{} = site, attrs \\ %{}) do
    Site.changeset(site, attrs)
  end

  @doc """
  Gets sites that need to be crawled (haven't been crawled recently).
  """
  def get_sites_needing_crawl(hours_threshold \\ 24) do
    threshold_datetime = NaiveDateTime.utc_now() |> NaiveDateTime.add(-hours_threshold * 3600, :second)

    from(s in Site,
      where: s.is_active == true and (is_nil(s.last_crawled_at) or s.last_crawled_at < ^threshold_datetime)
    )
    |> Repo.all()
  end

  @doc """
  Updates site's last crawled timestamp.
  """
  def mark_site_as_crawled(%Site{} = site) do
    update_site(site, %{last_crawled_at: NaiveDateTime.utc_now()})
  end

  # TOS Version functions

  @doc """
  Creates a new TOS version.
  """
  def create_tos_version(attrs \\ %{}) do
    %TosVersion{}
    |> TosVersion.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets the current TOS version for a site and content type.
  """
  def get_current_tos_version(site_id, content_type) do
    from(tv in TosVersion,
      where: tv.site_id == ^site_id and tv.content_type == ^content_type and tv.is_current == true,
      order_by: [desc: tv.detected_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Marks all previous versions as not current and creates a new current version.
  """
  def create_new_current_tos_version(site_id, content_type, attrs) do
    Repo.transaction(fn ->
      # Mark all previous versions as not current
      from(tv in TosVersion,
        where: tv.site_id == ^site_id and tv.content_type == ^content_type
      )
      |> Repo.update_all(set: [is_current: false])

      # Create new current version
      attrs = Map.merge(attrs, %{site_id: site_id, content_type: content_type, is_current: true})

      case create_tos_version(attrs) do
        {:ok, tos_version} -> tos_version
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Gets TOS version history for a site.
  """
  def get_tos_version_history(site_id, content_type) do
    from(tv in TosVersion,
      where: tv.site_id == ^site_id and tv.content_type == ^content_type,
      order_by: [desc: tv.detected_at]
    )
    |> Repo.all()
  end

  @doc """
  Checks if TOS content has changed by comparing hashes.
  """
  def has_tos_content_changed?(site_id, content_type, new_content_hash) do
    case get_current_tos_version(site_id, content_type) do
      nil -> true  # No previous version exists
      current_version -> current_version.version_hash != new_content_hash
    end
  end
end
