defmodule ObeliskWeb.ChatChannelTest do
  use ObeliskWeb.ChannelCase
  import Mock

  alias ObeliskWeb.{ChatChannel, UserSocket}
  alias Obelisk.{Chat, Memory}

  setup do
    # Create a test session
    {:ok, session} = Memory.get_or_create_session("test-channel-session")

    # Connect to socket
    {:ok, socket} = connect(UserSocket, %{})

    %{socket: socket, session: session}
  end

  describe "join chat:session_name" do
    test "joins successfully with valid session", %{socket: socket} do
      with_mocks([
        {Memory, [],
         [get_or_create_session: fn _name -> {:ok, %{id: 1, name: "test-session"}} end]},
        {Chat, [], [get_conversation_history: fn _id, _opts -> {:ok, []} end]}
      ]) do
        assert {:ok, _, joined_socket} =
                 subscribe_and_join(socket, ChatChannel, "chat:test-session")

        assert joined_socket.assigns.session_name == "test-session"
        assert joined_socket.assigns.session_id == 1
      end
    end

    test "fails to join with invalid session creation", %{socket: socket} do
      with_mock Memory, get_or_create_session: fn _name -> {:error, :database_error} end do
        assert {:error, %{reason: "Failed to access session"}} =
                 subscribe_and_join(socket, ChatChannel, "chat:invalid-session")
      end
    end

    test "fails to join with invalid topic format", %{socket: socket} do
      assert {:error, %{reason: reason}} =
               subscribe_and_join(socket, ChatChannel, "invalid:topic")

      assert String.contains?(reason, "Invalid chat topic format")
    end

    test "sends chat history after joining", %{socket: socket} do
      mock_history = [
        %{role: :user, content: %{text: "Hello"}, inserted_at: ~N[2025-01-01 00:00:00]},
        %{role: :assistant, content: %{text: "Hi there!"}, inserted_at: ~N[2025-01-01 00:00:01]}
      ]

      with_mocks([
        {Memory, [],
         [get_or_create_session: fn _name -> {:ok, %{id: 1, name: "test-session"}} end]},
        {Chat, [], [get_conversation_history: fn _id, _opts -> {:ok, mock_history} end]}
      ]) do
        assert {:ok, _, _socket} = subscribe_and_join(socket, ChatChannel, "chat:test-session")

        # Should receive chat history
        assert_push "chat_history", %{history: history}
        assert length(history) == 2
        assert Enum.at(history, 0).role == :user
        assert Enum.at(history, 1).role == :assistant
      end
    end
  end

  describe "handle_in new_message" do
    setup %{socket: socket} do
      with_mocks([
        {Memory, [],
         [get_or_create_session: fn _name -> {:ok, %{id: 1, name: "test-session"}} end]},
        {Chat, [], [get_conversation_history: fn _id, _opts -> {:ok, []} end]}
      ]) do
        {:ok, _, joined_socket} = subscribe_and_join(socket, ChatChannel, "chat:test-session")
        %{socket: joined_socket}
      end
    end

    test "handles successful message", %{socket: socket} do
      mock_result = %{
        response: "Hello! How can I help you?",
        context_used: 2,
        history_included: 1
      }

      with_mock Chat, send_message: fn _msg, _session, _opts -> {:ok, mock_result} end do
        ref = push(socket, "new_message", %{"message" => "Hello"})

        # Should reply with success
        assert_reply ref, :ok, reply
        assert reply.response == "Hello! How can I help you?"
        assert reply.context_used == 2
        assert reply.history_included == 1
        assert reply.session == "test-session"

        # Should broadcast typing indicators
        assert_broadcast "typing", %{user: "assistant", typing: true}
        assert_broadcast "typing", %{user: "assistant", typing: false}

        # Should broadcast user message
        assert_broadcast "new_message", user_msg
        assert user_msg.role == "user"
        assert user_msg.content.text == "Hello"

        # Should broadcast assistant message
        assert_broadcast "new_message", assistant_msg
        assert assistant_msg.role == "assistant"
        assert assistant_msg.content.text == "Hello! How can I help you?"
        assert assistant_msg.metadata.context_used == 2
      end
    end

    test "handles message errors", %{socket: socket} do
      with_mock Chat, send_message: fn _msg, _session, _opts -> {:error, :llm_failed} end do
        ref = push(socket, "new_message", %{"message" => "Hello"})

        # Should reply with error
        assert_reply ref, :error, %{reason: reason}
        assert String.contains?(reason, "LLM error")

        # Should stop typing indicator
        assert_broadcast "typing", %{user: "assistant", typing: false}
      end
    end
  end

  describe "handle_in stream_message" do
    setup %{socket: socket} do
      with_mocks([
        {Memory, [],
         [get_or_create_session: fn _name -> {:ok, %{id: 1, name: "test-session"}} end]},
        {Chat, [], [get_conversation_history: fn _id, _opts -> {:ok, []} end]}
      ]) do
        {:ok, _, joined_socket} = subscribe_and_join(socket, ChatChannel, "chat:test-session")
        %{socket: joined_socket}
      end
    end

    test "handles successful streaming message", %{socket: socket} do
      mock_result = %{
        response: "Hello there",
        context_used: 1,
        history_included: 0
      }

      with_mock Chat, send_message: fn _msg, _session, _opts -> {:ok, mock_result} end do
        ref = push(socket, "stream_message", %{"message" => "Hello"})

        # Should reply with streaming confirmation
        assert_reply ref, :ok, %{streaming: true, session: "test-session"}

        # Should push stream events
        assert_push "stream_start", %{session: "test-session", message: "Hello"}
        assert_push "stream_chunk", %{content: "Hello ", session: "test-session"}
        assert_push "stream_chunk", %{content: "there ", session: "test-session"}

        assert_push "stream_complete", %{
          session: "test-session",
          metadata: %{context_used: 1, history_included: 0}
        }

        # Should handle typing indicators
        assert_broadcast "typing", %{user: "assistant", typing: true}
        assert_broadcast "typing", %{user: "assistant", typing: false}
      end
    end

    test "handles streaming errors", %{socket: socket} do
      with_mock Chat, send_message: fn _msg, _session, _opts -> {:error, :api_timeout} end do
        ref = push(socket, "stream_message", %{"message" => "Hello"})

        # Should reply with error
        assert_reply ref, :error, %{reason: reason}
        assert String.contains?(reason, "api_timeout")

        # Should push stream error
        assert_push "stream_error", %{error: error, session: "test-session"}
        assert String.contains?(error, "api_timeout")

        # Should stop typing indicator
        assert_broadcast "typing", %{user: "assistant", typing: false}
      end
    end
  end

  describe "handle_in typing" do
    setup %{socket: socket} do
      with_mocks([
        {Memory, [],
         [get_or_create_session: fn _name -> {:ok, %{id: 1, name: "test-session"}} end]},
        {Chat, [], [get_conversation_history: fn _id, _opts -> {:ok, []} end]}
      ]) do
        {:ok, _, joined_socket} = subscribe_and_join(socket, ChatChannel, "chat:test-session")
        %{socket: joined_socket}
      end
    end

    test "broadcasts typing indicators to other users", %{socket: socket} do
      push(socket, "typing", %{"typing" => true, "user" => "john"})

      # Should broadcast typing to other users (not the sender)
      assert_broadcast "typing", %{user: "john", typing: true}
    end
  end

  describe "handle_in get_history" do
    setup %{socket: socket} do
      with_mocks([
        {Memory, [],
         [get_or_create_session: fn _name -> {:ok, %{id: 1, name: "test-session"}} end]},
        {Chat, [], [get_conversation_history: fn _id, _opts -> {:ok, []} end]}
      ]) do
        {:ok, _, joined_socket} = subscribe_and_join(socket, ChatChannel, "chat:test-session")
        %{socket: joined_socket}
      end
    end

    test "returns chat history successfully", %{socket: socket} do
      mock_history = [
        %{role: :user, content: %{text: "Hello"}, inserted_at: ~N[2025-01-01 00:00:00]},
        %{role: :assistant, content: %{text: "Hi!"}, inserted_at: ~N[2025-01-01 00:00:01]}
      ]

      with_mock Chat, get_conversation_history: fn _id, _opts -> {:ok, mock_history} end do
        ref = push(socket, "get_history", %{"max_history" => 10})

        assert_reply ref, :ok, %{history: history}
        assert length(history) == 2
        assert Enum.at(history, 0).role == :user
      end
    end

    test "handles history loading errors", %{socket: socket} do
      with_mock Chat, get_conversation_history: fn _id, _opts -> {:error, :database_error} end do
        ref = push(socket, "get_history", %{})

        assert_reply ref, :error, %{reason: reason}
        assert String.contains?(reason, "Failed to load history")
      end
    end
  end

  describe "handle_in clear_history" do
    setup %{socket: socket} do
      with_mocks([
        {Memory, [],
         [get_or_create_session: fn _name -> {:ok, %{id: 1, name: "test-session"}} end]},
        {Chat, [], [get_conversation_history: fn _id, _opts -> {:ok, []} end]}
      ]) do
        {:ok, _, joined_socket} = subscribe_and_join(socket, ChatChannel, "chat:test-session")
        %{socket: joined_socket}
      end
    end

    test "clears history successfully", %{socket: socket} do
      with_mock Chat, clear_history: fn _session -> {:ok, :cleared} end do
        ref = push(socket, "clear_history", %{})

        assert_reply ref, :ok, %{cleared: true}

        # Should broadcast to all users in channel
        assert_broadcast "history_cleared", %{session: "test-session"}
      end
    end

    test "handles clear history errors", %{socket: socket} do
      with_mock Chat, clear_history: fn _session -> {:error, :permission_denied} end do
        ref = push(socket, "clear_history", %{})

        assert_reply ref, :error, %{reason: reason}
        assert String.contains?(reason, "Failed to clear history")
      end
    end
  end

  describe "terminate" do
    test "logs user leaving session", %{socket: socket} do
      with_mocks([
        {Memory, [],
         [get_or_create_session: fn _name -> {:ok, %{id: 1, name: "test-session"}} end]},
        {Chat, [], [get_conversation_history: fn _id, _opts -> {:ok, []} end]}
      ]) do
        {:ok, _, joined_socket} = subscribe_and_join(socket, ChatChannel, "chat:test-session")

        # Should handle termination gracefully
        assert :ok = ChatChannel.terminate(:normal, joined_socket)
      end
    end
  end
end
