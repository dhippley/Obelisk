defmodule Obelisk.Tools.Echo do
  @moduledoc """
  Simple echo tool for testing the MCP server functionality.

  This tool simply returns the message that was sent to it, along with
  some metadata about the execution context. Useful for testing and
  debugging the tool system.
  """

  @behaviour Obelisk.Tool

  @impl true
  def spec do
    %{
      name: "echo",
      description: "Echo back the provided message with metadata",
      params: %{
        type: "object",
        properties: %{
          message: %{
            type: "string",
            description: "The message to echo back"
          }
        },
        required: ["message"]
      }
    }
  end

  @impl true
  def call(%{"message" => message}, ctx) do
    {:ok,
     %{
       echoed_message: message,
       context: %{
         session_id: Map.get(ctx, :session_id),
         timestamp: Map.get(ctx, :timestamp),
         request_id: Map.get(ctx, :request_id)
       },
       message_length: String.length(message),
       message_words: count_words(message)
     }}
  end

  defp count_words(message) do
    trimmed = String.trim(message)

    if trimmed == "" do
      0
    else
      trimmed
      |> String.split(~r/\s+/)
      |> length()
    end
  end
end
