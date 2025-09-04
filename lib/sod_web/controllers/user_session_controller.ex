defmodule SodWeb.UserSessionController do
  use SodWeb, :controller

  alias Sod.Accounts
  alias SodWeb.UserAuth
  alias Sod.Sessions

  

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # defp create(conn, %{"user" => user_params}, info) do
  #   %{"email" => email, "password" => password} = user_params

  #   if user = Accounts.get_user_by_email_and_password(email, password) do
  #     conn
  #     |> put_flash(:info, info)
  #     |> UserAuth.log_in_user(user, user_params)
  #   else
  #     # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
  #     conn
  #     |> put_flash(:error, "Invalid email or password")
  #     |> put_flash(:email, String.slice(email, 0, 160))
  #     |> redirect(to: ~p"/users/log_in")
  #   end
  # end

  # def delete(conn, _params) do
  #   conn
  #   |> put_flash(:info, "Logged out successfully.")
  #   |> UserAuth.log_out_user()
  # end

  def create(conn, %{"user" => user_params}, message) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      IO.inspect(user.id)
      # Always create/update a browser session on login
      _ = Sessions.handle_user_login(user.id, extract_browser_session_params(conn))
      token = Accounts.UserToken.by_token_and_context_query(user, "session")
      conn
      |> put_flash(:info, message)
      |> UserAuth.log_in_user(user)
      |> redirect(to: "/")
      |> assign(:auth_data, %{
        auth_token: token,
        user_id: user.id,
        expires_at: DateTime.add(DateTime.utc_now(), 60 * 60 * 24 * 7, :second), # Assuming 7 days expiry
        is_authenticated: true
      })
    else
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log_in")
    end
  end

  # Add logout handling for browser sessions
  def delete(conn, _params) do
    # Optionally, you can deactivate all sessions for the user here if desired
    # current_user = conn.assigns[:current_user]
    # if current_user, do: Sessions.deactivate_all_user_sessions(current_user.id)

    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
    |> redirect(to: "/")
  end

  # Helper functions
  defp extract_browser_session_params(conn) do
    headers = conn.req_headers |> Enum.into(%{})

    %{
      "user_agent" => get_req_header(conn, "user-agent") |> List.first(),
      "ip_address" => get_client_ip(conn),
      "extension_version" => headers["x-extension-version"] || "0.0.1",
      "browser_fingerprint" => headers["x-browser-fingerprint"]
      }
  end

  defp get_client_ip(conn) do
    conn
    |> get_req_header("x-forwarded-for")
    |> List.first()
    |> case do
      nil ->
        conn
        |> get_req_header("x-real-ip")
        |> List.first()
        |> case do
          nil ->
            conn.remote_ip
            |> :inet_parse.ntoa()
            |> to_string()
          ip -> ip
        end
      forwarded ->
        forwarded
        |> String.split(",")
        |> List.first()
        |> String.trim()
    end
  end

#   defp get_or_create_user_token(user) do
#   case Accounts.UserToken.by_token_and_context_query(user, "session") do
#     nil ->
#       # Create new token if none exists
#       {:ok, token} = Accounts.generate_user_session_token(user)
#       token
#     existing_token ->
#       existing_token
#   end
# end
end
