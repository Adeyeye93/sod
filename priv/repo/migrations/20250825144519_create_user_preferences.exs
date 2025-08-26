defmodule Sod.Repo.Migrations.CreateUserPreferences do
  use Ecto.Migration

 def change do
    create table(:user_preferences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # Data Sharing & Selling
      add :allow_data_selling, :boolean, default: false
      add :allow_third_party_sharing, :boolean, default: false
      add :allow_marketing_data_sharing, :boolean, default: false
      add :allow_analytics_data_sharing, :boolean, default: true
      add :allow_anonymized_data_selling, :boolean, default: true
      add :allow_affiliate_sharing, :boolean, default: false
      add :allow_law_enforcement_sharing_no_warrant, :boolean, default: false

      # Data Collection
      add :allow_usage_analytics, :boolean, default: true
      add :allow_precise_location, :boolean, default: false
      add :allow_approximate_location, :boolean, default: false
      add :allow_contacts_access, :boolean, default: false
      add :allow_calendar_access, :boolean, default: false
      add :allow_camera_access, :boolean, default: false
      add :allow_microphone_access, :boolean, default: false
      add :allow_photos_access, :boolean, default: false
      add :allow_clipboard_reading, :boolean, default: false
      add :allow_keyboard_input_reading, :boolean, default: false

      # Personalization & Tracking
      add :allow_personalized_ads, :boolean, default: true
      add :allow_cross_site_tracking, :boolean, default: false
      add :allow_profiling, :boolean, default: true
      add :allow_behavioral_tracking_ai, :boolean, default: false

      # Data Retention & Deletion
      add :allow_indefinite_retention, :boolean, default: false
      add :allow_retention_after_deletion, :boolean, default: false
      add :allow_data_use_after_deletion, :boolean, default: false

      # Employee Access & Internal Use
      add :allow_employee_data_access, :boolean, default: false
      add :allow_ai_training_on_data, :boolean, default: false
      add :allow_support_message_reading, :boolean, default: true
      add :allow_internal_file_review, :boolean, default: false

      # Cross-Border Data Transfer
      add :allow_international_transfer, :boolean, default: true
      add :allow_low_protection_countries, :boolean, default: false

      # Security Practices
      add :allow_weak_encryption_at_rest, :boolean, default: false
      add :allow_no_encryption_in_transit, :boolean, default: false
      add :allow_password_hash_sharing, :boolean, default: false

      # AI-Specific Concerns
      add :allow_ai_conversation_analysis, :boolean, default: false
      add :allow_ai_public_data_generation, :boolean, default: false
      add :allow_synthetic_data_generation, :boolean, default: false

      # Communication & Contact
      add :allow_marketing_emails, :boolean, default: true
      add :allow_sms_marketing, :boolean, default: false
      add :allow_robocalls, :boolean, default: false

      # Miscellaneous
      add :allow_background_data_collection, :boolean, default: false
      add :allow_background_location_tracking, :boolean, default: false
      add :allow_additional_software_install, :boolean, default: false
      add :allow_auto_subscription_renewal, :boolean, default: true
      add :allow_arbitration_clause, :boolean, default: false
      add :allow_class_action_waiver, :boolean, default: false

      # Keyboard & Clipboard
      add :allow_external_keyboard_reading, :boolean, default: false
      add :allow_clipboard_monitoring, :boolean, default: false

      timestamps()
    end

    create unique_index(:user_preferences, [:user_id])
  end
end
