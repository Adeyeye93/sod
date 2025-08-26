defmodule Sod.Sites.TosVersion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tos_versions" do
    belongs_to :site, Sod.Sites.Site

    field :version_hash, :string
    field :content, :string
    field :content_type, :string # "terms_of_service" | "privacy_policy"
    field :detected_at, :naive_datetime
    field :is_current, :boolean, default: true

    timestamps()
  end

  def changeset(tos_version, attrs) do
    tos_version
    |> cast(attrs, [:version_hash, :content, :content_type, :detected_at, :is_current])
    |> validate_required([:version_hash, :content, :content_type, :detected_at])
    |> validate_inclusion(:content_type, ["terms_of_service", "privacy_policy"])
  end
end
