defmodule Obelisk.Tools.Memory do
  @moduledoc """
  Tool for searching and managing Obelisk's memory system.

  This tool provides access to the semantic memory search functionality,
  allowing AI agents to retrieve relevant information from stored memories.
  """

  @behaviour Obelisk.Tool

  @impl true
  def spec do
    %{
      name: "memory_search",
      description: "Search through stored memories using semantic similarity",
      params: %{
        type: "object",
        properties: %{
          query: %{
            type: "string",
            description: "The search query to find relevant memories"
          },
          k: %{
            type: "integer",
            description: "Number of results to return (default: 5)",
            minimum: 1,
            maximum: 50
          },
          session_id: %{
            type: "string",
            description: "Optional session ID to scope the search"
          },
          threshold: %{
            type: "number",
            description: "Minimum similarity threshold (default: 0.7)",
            minimum: 0.0,
            maximum: 1.0
          }
        },
        required: ["query"]
      }
    }
  end

  @impl true
  def call(params, ctx) do
    query = Map.get(params, "query")
    k = Map.get(params, "k", 5)
    session_id = Map.get(params, "session_id") || Map.get(ctx, :session_id)
    threshold = Map.get(params, "threshold", 0.7)

    try do
      # Use the existing Retrieval module to search memories
      results = Obelisk.Retrieval.retrieve(query, session_id, k, %{threshold: threshold})

      # Format results for tool response
      formatted_results =
        results
        |> Enum.map(fn result ->
          %{
            id: result.id,
            text: result.text,
            kind: result.kind,
            score: result.score,
            session_id: result.session_id,
            inserted_at: result.inserted_at
          }
        end)

      {:ok,
       %{
         query: query,
         results: formatted_results,
         total_found: length(formatted_results),
         search_params: %{
           k: k,
           session_id: session_id,
           threshold: threshold
         }
       }}
    rescue
      error ->
        {:error, "Memory search failed: #{inspect(error)}"}
    end
  end
end
