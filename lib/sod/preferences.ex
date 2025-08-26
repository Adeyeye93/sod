defmodule Sod.Preferences do
  @moduledoc """
  The Preferences context for managing user privacy preferences.
  """

  import Ecto.Query, warn: false
  alias Sod.Repo
  alias Sod.Preference.UserPreference
  alias Sod.Accounts.User

  @doc """
  Returns the list of user_preferences.
  """
  def list_user_preferences do
    Repo.all(UserPreference)
  end

  @doc """
  Gets a single user_preference.
  """
  def get_user_preference!(id), do: Repo.get!(UserPreference, id)

  @doc """
  Gets user preferences by user ID.
  """
  def get_user_preference_by_user_id(user_id) do
    Repo.get_by(UserPreference, user_id: user_id)
  end

  @doc """
  Gets or creates user preferences for a user.
  """
  def get_or_create_user_preference(%User{id: user_id}) do
    case get_user_preference_by_user_id(user_id) do
      nil ->
        create_user_preference(%{user_id: user_id})
      preference ->
        {:ok, preference}
    end
  end

  @doc """
  Creates a user_preference.
  """
  def create_user_preference(attrs \\ %{}) do
    %UserPreference{}
    |> UserPreference.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user_preference.
  """
  def update_user_preference(%UserPreference{} = user_preference, attrs) do
    user_preference
    |> UserPreference.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user_preference.
  """
  def delete_user_preference(%UserPreference{} = user_preference) do
    Repo.delete(user_preference)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_preference changes.
  """
  def change_user_preference(%UserPreference{} = user_preference, attrs \\ %{}) do
    UserPreference.changeset(user_preference, attrs)
  end

  @doc """
  Gets preference fields that are set to false (restrictive preferences).
  """
  def get_restrictive_preferences(%UserPreference{} = preference) do
    preference
    |> Map.from_struct()
    |> Enum.filter(fn {key, value} ->
      is_boolean(value) && value == false && key != :__meta__ && key != :id && key != :user_id
    end)
    |> Enum.map(fn {key, _value} -> Atom.to_string(key) end)
  end

  @doc """
  Checks if a site practice violates user preferences.
  """
  def check_preference_violations(%UserPreference{} = preference, detected_practices) when is_map(detected_practices) do
    restrictive_preferences = get_restrictive_preferences(preference)

    Enum.filter(detected_practices, fn {practice, detected} ->
      detected && Enum.member?(restrictive_preferences, practice)
    end)
  end
end
