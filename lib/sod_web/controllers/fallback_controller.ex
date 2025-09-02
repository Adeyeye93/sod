defmodule SodWeb.FallbackController do
  use SodWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: SodWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: SodWeb.ErrorJSON)
    |> render(:"401")
  end

  def call(conn, {:error, :preferences_not_found}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: SodWeb.ErrorJSON)
    |> render(:error, %{message: "User preferences not found or could not be created"})
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: SodWeb.ErrorJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, _}) do
    conn
    |> put_status(:internal_server_error)
    |> put_view(json: SodWeb.ErrorJSON)
    |> render(:"500")
  end
end
