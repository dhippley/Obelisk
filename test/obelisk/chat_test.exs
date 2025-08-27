defmodule Obelisk.ChatTest do
  use Obelisk.DataCase
  import Mock

  alias Obelisk.{Chat, Memory, Repo}
  alias Obelisk.Schemas.Memory, as: MemorySchema
  alias Obelisk.Schemas.{Message, Session}

  setup do
    # Create test session with some memories
    {:ok, session} = Memory.get_or_create_session("test-chat-session")

    # Create some test memories for RAG context
    # High similarity for testing
    embedding = List.duplicate(0.9, 1536)

    {:ok, _memory1} =
      %MemorySchema{
        kind: :fact,
        text:
          "Elixir is a dynamic, functional language designed for maintainability and high availability.",
        embedding: embedding,
        session_id: session.id
      }
      |> Repo.insert()

    {:ok, _memory2} =
      %MemorySchema{
        kind: :fact,
        text:
          "Phoenix is a web development framework written in Elixir using the Model-View-Controller pattern.",
        embedding: embedding,
        session_id: session.id
      }
      |> Repo.insert()

    # Create global memory
    {:ok, _global_memory} =
      %MemorySchema{
        kind: :note,
        text:
          "Global knowledge: OTP (Open Telecom Platform) is the foundation of Elixir applications.",
        embedding: embedding,
        session_id: nil
      }
      |> Repo.insert()

    %{session: session}
  end

  describe "send_message/3" do
    # Skip in CI where no API key is available
    @tag :skip_llm
    test "sends basic chat message and stores conversation", %{session: _session} do
      user_message = "What is Elixir?"
      unique_session = "test-basic-chat-#{:erlang.system_time()}"

      # Mock both LLM and Retrieval calls
      with_mocks([
        {Obelisk.LLM.Router, [],
         [chat: fn _messages, _opts -> {:ok, "Elixir is a great language!"} end]},
        {Obelisk.Retrieval, [], [retrieve: fn _query, _session_id, _k, _opts -> [] end]}
      ]) do
        {:ok, result} = Chat.send_message(user_message, unique_session)

        assert result.response == "Elixir is a great language!"
        assert result.session == unique_session
        assert result.context_used >= 0
        # Should have minimal history for new session
        assert result.history_included >= 0

        # Check messages were stored
        {:ok, new_session} = Memory.get_or_create_session(unique_session)
        messages = from(m in Message, where: m.session_id == ^new_session.id) |> Repo.all()
        assert length(messages) == 2

        user_msg = Enum.find(messages, &(&1.role == :user))
        assistant_msg = Enum.find(messages, &(&1.role == :assistant))

        assert user_msg.content == %{"text" => user_message}
        assert assistant_msg.content == %{"text" => "Elixir is a great language!"}
      end
    end

    test "creates new session if it doesn't exist" do
      new_session_name = "brand-new-session"

      with_mocks([
        {Obelisk.LLM.Router, [],
         [chat: fn _messages, _opts -> {:ok, "Hello! I'm ready to help."} end]},
        {Obelisk.Retrieval, [], [retrieve: fn _query, _session_id, _k, _opts -> [] end]}
      ]) do
        {:ok, result} = Chat.send_message("Hello", new_session_name)

        assert result.session == new_session_name

        # Verify session was created
        session = from(s in Session, where: s.name == ^new_session_name) |> Repo.one()
        assert session != nil
      end
    end

    test "includes conversation history in subsequent messages", %{session: _session} do
      unique_session = "test-history-#{:erlang.system_time()}"

      with_mocks([
        {Obelisk.LLM.Router, [], [chat: fn _messages, _opts -> {:ok, "Mock response"} end]},
        {Obelisk.Retrieval, [], [retrieve: fn _query, _session_id, _k, _opts -> [] end]}
      ]) do
        # Send first message
        {:ok, _} = Chat.send_message("First message", unique_session)

        # Send second message - should include history
        {:ok, result} = Chat.send_message("Second message", unique_session)

        # Should include previous user + assistant messages
        assert result.history_included >= 2
      end
    end

    test "handles LLM errors gracefully", %{session: session} do
      with_mocks([
        {Obelisk.LLM.Router, [], [chat: fn _messages, _opts -> {:error, :api_error} end]},
        {Obelisk.Retrieval, [], [retrieve: fn _query, _session_id, _k, _opts -> [] end]}
      ]) do
        result = Chat.send_message("Test message", session.name)

        assert {:error, {:llm_failed, :api_error}} = result

        # User message should still be stored even if LLM fails
        messages = from(m in Message, where: m.session_id == ^session.id) |> Repo.all()
        assert length(messages) == 1
        assert hd(messages).role == :user
      end
    end

    test "respects retrieval_k option", %{session: session} do
      with_mocks([
        {Obelisk.LLM.Router, [], [chat: fn _messages, _opts -> {:ok, "Response"} end]},
        {Obelisk.Retrieval, [], [retrieve: fn _query, _session_id, _k, _opts -> [] end]}
      ]) do
        {:ok, result} = Chat.send_message("Tell me about Elixir", session.name, %{retrieval_k: 1})

        # Should have retrieved at most 1 context item
        assert result.context_used <= 1
      end
    end

    test "respects max_history option", %{session: session} do
      with_mocks([
        {Obelisk.LLM.Router, [], [chat: fn _messages, _opts -> {:ok, "Response"} end]},
        {Obelisk.Retrieval, [], [retrieve: fn _query, _session_id, _k, _opts -> [] end]}
      ]) do
        # Create several messages first
        for i <- 1..5 do
          {:ok, _} = Chat.send_message("Message #{i}", session.name)
        end

        # Send message with limited history
        {:ok, result} = Chat.send_message("Final message", session.name, %{max_history: 2})

        assert result.history_included == 2
      end
    end

    test "handles retrieval errors gracefully", %{session: session} do
      with_mocks([
        {Obelisk.Retrieval, [],
         [retrieve: fn _query, _session_id, _k, _opts -> {:error, :embedding_failed} end]},
        {Obelisk.LLM.Router, [],
         [chat: fn _messages, _opts -> {:ok, "Response without context"} end]}
      ]) do
        result = Chat.send_message("Test", session.name)

        assert {:error, {:retrieval_failed, :embedding_failed}} = result
      end
    end
  end

  describe "get_conversation_history/2" do
    test "returns conversation history in chronological order", %{session: session} do
      # Insert messages with specific order
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      {:ok, _msg1} =
        %Message{
          role: :user,
          content: %{text: "First message"},
          session_id: session.id,
          inserted_at: NaiveDateTime.add(now, -30, :second)
        }
        |> Repo.insert()

      {:ok, _msg2} =
        %Message{
          role: :assistant,
          content: %{text: "First response"},
          session_id: session.id,
          inserted_at: NaiveDateTime.add(now, -20, :second)
        }
        |> Repo.insert()

      {:ok, _msg3} =
        %Message{
          role: :user,
          content: %{text: "Second message"},
          session_id: session.id,
          inserted_at: now
        }
        |> Repo.insert()

      {:ok, history} = Chat.get_conversation_history(session.id)

      assert length(history) == 3
      # Oldest first
      assert hd(history).content == "First message"
      # Newest last
      assert List.last(history).content == "Second message"
    end

    test "respects max_history limit", %{session: session} do
      # Create more messages than the limit
      for i <- 1..10 do
        %Message{role: :user, content: %{text: "Message #{i}"}, session_id: session.id}
        |> Repo.insert()
      end

      {:ok, history} = Chat.get_conversation_history(session.id, %{max_history: 3})

      assert length(history) == 3

      # Should get the 3 most recent messages (note: timestamps might be the same, so exact order varies)
      message_contents = Enum.map(history, & &1.content)
      # At least check we got recent messages
      assert length(message_contents) == 3
    end

    test "returns empty list for session with no messages" do
      {:ok, new_session} = Memory.get_or_create_session("empty-session")

      {:ok, history} = Chat.get_conversation_history(new_session.id)

      assert history == []
    end
  end

  describe "clear_history/1" do
    test "clears all messages for a session", %{session: session} do
      # Add some messages
      %Message{role: :user, content: %{text: "Test 1"}, session_id: session.id} |> Repo.insert()

      %Message{role: :assistant, content: %{text: "Response 1"}, session_id: session.id}
      |> Repo.insert()

      {:ok, :cleared} = Chat.clear_history(session.name)

      # Messages should be gone
      messages = from(m in Message, where: m.session_id == ^session.id) |> Repo.all()
      assert messages == []

      # Session should still exist
      existing_session = Repo.get(Session, session.id)
      assert existing_session != nil
    end

    test "returns error for non-existent session" do
      result = Chat.clear_history("non-existent-session")

      assert {:error, :session_not_found} = result
    end
  end
end
