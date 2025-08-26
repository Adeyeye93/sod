defmodule Sod.Preference.UserPreference do
   use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_preferences" do
    belongs_to :user, Sod.Accounts.User

    # 1. Data Sharing & Selling
    field :allow_data_selling, :boolean, default: false
    field :allow_third_party_sharing, :boolean, default: false
    field :allow_marketing_data_sharing, :boolean, default: false
    field :allow_analytics_data_sharing, :boolean, default: true
    field :allow_anonymized_data_selling, :boolean, default: true
    field :allow_affiliate_sharing, :boolean, default: false
    field :allow_law_enforcement_sharing_no_warrant, :boolean, default: false

    # 2. Data Collection
    field :allow_usage_analytics, :boolean, default: true
    field :allow_precise_location, :boolean, default: false
    field :allow_approximate_location, :boolean, default: false
    field :allow_contacts_access, :boolean, default: false
    field :allow_calendar_access, :boolean, default: false
    field :allow_camera_access, :boolean, default: false
    field :allow_microphone_access, :boolean, default: false
    field :allow_photos_access, :boolean, default: false
    field :allow_clipboard_reading, :boolean, default: false
    field :allow_keyboard_input_reading, :boolean, default: false

    # 3. Personalization & Tracking
    field :allow_personalized_ads, :boolean, default: true
    field :allow_cross_site_tracking, :boolean, default: false
    field :allow_profiling, :boolean, default: true
    field :allow_behavioral_tracking_ai, :boolean, default: false

    # 4. Data Retention & Deletion
    field :allow_indefinite_retention, :boolean, default: false
    field :allow_retention_after_deletion, :boolean, default: false
    field :allow_data_use_after_deletion, :boolean, default: false

    # 5. Employee Access & Internal Use
    field :allow_employee_data_access, :boolean, default: false
    field :allow_ai_training_on_data, :boolean, default: false
    field :allow_support_message_reading, :boolean, default: true
    field :allow_internal_file_review, :boolean, default: false

    # 6. Cross-Border Data Transfer
    field :allow_international_transfer, :boolean, default: true
    field :allow_low_protection_countries, :boolean, default: false

    # 7. Security Practices
    field :allow_weak_encryption_at_rest, :boolean, default: false
    field :allow_no_encryption_in_transit, :boolean, default: false
    field :allow_password_hash_sharing, :boolean, default: false

    # 8. AI-Specific Concerns
    field :allow_ai_conversation_analysis, :boolean, default: false
    field :allow_ai_public_data_generation, :boolean, default: false
    field :allow_synthetic_data_generation, :boolean, default: false

    # 9. Communication & Contact
    field :allow_marketing_emails, :boolean, default: true
    field :allow_sms_marketing, :boolean, default: false
    field :allow_robocalls, :boolean, default: false

    # 10. Miscellaneous Potentially Risky Practices
    field :allow_background_data_collection, :boolean, default: false
    field :allow_background_location_tracking, :boolean, default: false
    field :allow_additional_software_install, :boolean, default: false
    field :allow_auto_subscription_renewal, :boolean, default: true
    field :allow_arbitration_clause, :boolean, default: false
    field :allow_class_action_waiver, :boolean, default: false

    # Bonus: Keyboard & Clipboard Specific
    field :allow_external_keyboard_reading, :boolean, default: false
    field :allow_clipboard_monitoring, :boolean, default: false

    timestamps()
  end

  def changeset(user_preference, attrs) do
    user_preference
    |> cast(attrs, [
      # Data Sharing & Selling
      :allow_data_selling, :allow_third_party_sharing, :allow_marketing_data_sharing,
      :allow_analytics_data_sharing, :allow_anonymized_data_selling, :allow_affiliate_sharing,
      :allow_law_enforcement_sharing_no_warrant,

      # Data Collection
      :allow_usage_analytics, :allow_precise_location, :allow_approximate_location,
      :allow_contacts_access, :allow_calendar_access, :allow_camera_access,
      :allow_microphone_access, :allow_photos_access, :allow_clipboard_reading,
      :allow_keyboard_input_reading,

      # Personalization & Tracking
      :allow_personalized_ads, :allow_cross_site_tracking, :allow_profiling,
      :allow_behavioral_tracking_ai,

      # Data Retention & Deletion
      :allow_indefinite_retention, :allow_retention_after_deletion, :allow_data_use_after_deletion,

      # Employee Access & Internal Use
      :allow_employee_data_access, :allow_ai_training_on_data, :allow_support_message_reading,
      :allow_internal_file_review,

      # Cross-Border Data Transfer
      :allow_international_transfer, :allow_low_protection_countries,

      # Security Practices
      :allow_weak_encryption_at_rest, :allow_no_encryption_in_transit, :allow_password_hash_sharing,

      # AI-Specific Concerns
      :allow_ai_conversation_analysis, :allow_ai_public_data_generation, :allow_synthetic_data_generation,

      # Communication & Contact
      :allow_marketing_emails, :allow_sms_marketing, :allow_robocalls,

      # Miscellaneous
      :allow_background_data_collection, :allow_background_location_tracking,
      :allow_additional_software_install, :allow_auto_subscription_renewal,
      :allow_arbitration_clause, :allow_class_action_waiver,

      # Keyboard & Clipboard
      :allow_external_keyboard_reading, :allow_clipboard_monitoring
    ])
  end
end
