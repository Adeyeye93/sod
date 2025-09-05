defmodule Sod.Repo.Migrations.IncreaseBrowserSessionFieldLengths do
  use Ecto.Migration

  def up do
    # Increase length limits for browser session fields that may contain long data
    alter table(:browser_sessions) do
      # Browser fingerprint can be a long base64 encoded JSON object
      modify :browser_fingerprint, :text
      # User agent strings can also be quite long (up to 512+ chars)
      modify :user_agent, :string, size: 1000
      # Session token might also need more space for certain implementations
      modify :session_token, :string, size: 500
    end
  end

  def down do
    # Note: This rollback may cause data loss if existing records exceed the original limits
    alter table(:browser_sessions) do
      modify :browser_fingerprint, :string, size: 255
      modify :user_agent, :string, size: 255
      modify :session_token, :string, size: 255
    end
  end
end
