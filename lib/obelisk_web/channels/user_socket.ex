defmodule ObeliskWeb.UserSocket do
  @moduledoc """
  Phoenix UserSocket for WebSocket connections.

  Handles authentication and channel routing for real-time features.
  """

  use Phoenix.Socket

  # Channels
  channel "chat:*", ObeliskWeb.ChatChannel

  @doc """
  Socket connection authentication.

  For now, we allow all connections. In production, you would
  authenticate users here based on tokens, session data, etc.
  """
  @impl true
  def connect(_params, socket, _connect_info) do
    # For demo purposes, allow all connections
    # In production, verify authentication here:
    #
    # case verify_token(params["token"]) do
    #   {:ok, user_id} ->
    #     socket = assign(socket, :user_id, user_id)
    #     {:ok, socket}
    #   {:error, _} ->
    #     :error
    # end

    {:ok, socket}
  end

  @doc """
  Socket ID for identifying connections.

  This is used for disconnecting users when needed.
  """
  @impl true
  def id(_socket) do
    # In production, you might use:
    # "user_socket:#{socket.assigns.user_id}"
    nil
  end
end
