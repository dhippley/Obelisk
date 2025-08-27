defmodule Obelisk.Chat do
  @moduledoc """
  Chat interface with Retrieval-Augmented Generation (RAG).

  Combines vector search, LLM providers, and conversation management
  to provide an intelligent chat experience powered by stored memories.
  """

  alias Obelisk.{LLM, Memory, Repo, Retrieval}
  alias Obelisk.Schemas.{Message, Session}
  import Ecto.Query

  @default_retrieval_k 5
  @default_model "gpt-3.5-turbo"
  @default_max_history 10

  @doc """
  Send a chat message and get an AI response with RAG.

  ## Options
  - `:model` - LLM model to use (default: "gpt-3.5-turbo")
  - `:retrieval_k` - Number of relevant memories to retrieve (default: 5)
  - `:retrieval_threshold` - Similarity threshold for memory retrieval (default: 0.7)
  - `:max_history` - Maximum conversation history to include (default: 10)
  - `:include_global_memories` - Whether to search global memories (default: true)

  ## Examples

      # Basic chat
      {:ok, response} = Chat.send_message("What is Elixir?", "my-session")

      # With custom options
      {:ok, response} = Chat.send_message("Tell me about Phoenix", "my-session", %{
        model: "gpt-4",
        retrieval_k: 10,
        max_history: 5
      })
  """
  def send_message(user_message, session_name, opts \\ %{})
      when is_binary(user_message) and is_binary(session_name) do
    with {:ok, session} <- Memory.get_or_create_session(session_name),
         {:ok, _user_msg} <- store_user_message(user_message, session.id),
         {:ok, context} <- retrieve_context(user_message, session.id, opts),
         {:ok, history} <- get_conversation_history(session.id, opts),
         {:ok, prompt} <- build_rag_prompt(user_message, context, history),
         {:ok, response} <- get_llm_response(prompt, opts),
         {:ok, _assistant_msg} <- store_assistant_message(response, session.id) do
      {:ok,
       %{
         response: response,
         session: session_name,
         context_used: length(context),
         history_included: length(history)
       }}
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, {:unexpected_error, error}}
    end
  end

  @doc """
  Get conversation history for a session.

  Returns list of messages ordered by most recent first.
  """
  def get_conversation_history(session_id, opts \\ %{}) do
    max_history = Map.get(opts, :max_history, @default_max_history)

    messages =
      from(m in Message,
        where: m.session_id == ^session_id,
        order_by: [desc: m.inserted_at],
        limit: ^max_history,
        select: %{role: m.role, content: m.content, inserted_at: m.inserted_at}
      )
      |> Repo.all()
      |> Enum.map(fn msg ->
        # Extract text from content map for simple display
        content = get_in(msg.content, ["text"]) || msg.content
        %{msg | content: content}
      end)
      # Reverse to get chronological order
      |> Enum.reverse()

    {:ok, messages}
  end

  @doc """
  Clear conversation history for a session.

  Deletes all messages but keeps the session and memories intact.
  """
  def clear_history(session_name) when is_binary(session_name) do
    case get_session_by_name(session_name) do
      nil ->
        {:error, :session_not_found}

      session ->
        from(m in Message, where: m.session_id == ^session.id)
        |> Repo.delete_all()

        {:ok, :cleared}
    end
  end

  # Private functions

  defp store_user_message(content, session_id) do
    %Message{
      role: :user,
      content: %{text: content},
      session_id: session_id
    }
    |> Repo.insert()
  end

  defp store_assistant_message(content, session_id) do
    %Message{
      role: :assistant,
      content: %{text: content},
      session_id: session_id
    }
    |> Repo.insert()
  end

  defp retrieve_context(query, session_id, opts) do
    k = Map.get(opts, :retrieval_k, @default_retrieval_k)
    threshold = Map.get(opts, :retrieval_threshold, 0.7)
    include_global = Map.get(opts, :include_global_memories, true)

    retrieval_opts = %{
      threshold: threshold,
      include_global: include_global
    }

    case Retrieval.retrieve(query, session_id, k, retrieval_opts) do
      {:ok, results} -> {:ok, results}
      {:error, reason} -> {:error, {:retrieval_failed, reason}}
      # Handle direct list return
      results when is_list(results) -> {:ok, results}
    end
  end

  defp build_rag_prompt(user_message, context, history) do
    system_prompt = """
    You are an intelligent assistant with access to relevant context from previous conversations and stored knowledge. Use this context to provide accurate, helpful responses.

    When answering:
    - Draw upon the provided context when relevant
    - Reference specific information from context when appropriate
    - If context doesn't contain relevant information, use your general knowledge
    - Be conversational and helpful
    - Maintain context from the conversation history
    """

    context_section =
      if context != [] do
        context_text =
          Enum.map_join(context, "\n", fn chunk -> "- #{chunk.text}" end)

        "\n\nRelevant context from memory:\n#{context_text}\n"
      else
        ""
      end

    history_section =
      if history != [] do
        history_text =
          Enum.map_join(history, "\n", fn msg ->
            content = msg.content || "No content"
            "#{String.capitalize(to_string(msg.role))}: #{content}"
          end)

        "\n\nConversation history:\n#{history_text}\n"
      else
        ""
      end

    prompt =
      system_prompt <>
        context_section <> history_section <> "\n\nUser: #{user_message}\nAssistant:"

    {:ok, prompt}
  end

  defp get_llm_response(prompt, opts) do
    model = Map.get(opts, :model, @default_model)

    messages = [
      %{role: "user", content: prompt}
    ]

    case LLM.Router.chat(messages, %{model: model}) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, {:llm_failed, reason}}
    end
  end

  defp get_session_by_name(session_name) do
    from(s in Session, where: s.name == ^session_name)
    |> Repo.one()
  end
end
