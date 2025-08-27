defmodule ObeliskWeb.Api.V1.ChatControllerTest do
  use ObeliskWeb.ConnCase
  import Mock

  alias Obelisk.{Chat, Memory}

  setup do
    # Create a test session
    {:ok, session} = Memory.get_or_create_session("test-api-session")
    %{session: session}
  end

  describe "POST /api/v1/chat" do
    test "creates chat message successfully", %{conn: conn} do
      with_mocks([
        {Chat, [],
         [
           send_message: fn _msg, _session, _opts ->
             {:ok,
              %{
                response: "Hello! How can I help you?",
                session: "test-session",
                context_used: 0,
                history_included: 0
              }}
           end
         ]}
      ]) do
        response =
          conn
          |> post("/api/v1/chat", %{
            message: "Hello",
            session_id: "test-session"
          })
          |> json_response(200)

        assert response["response"] == "Hello! How can I help you?"
        assert response["session_id"] == "test-session"
        assert response["context_used"] == 0
        assert response["history_included"] == 0
        assert Map.has_key?(response, "metadata")
      end
    end

    test "returns error for missing message", %{conn: conn} do
      response =
        conn
        |> post("/api/v1/chat", %{session_id: "test-session"})
        |> json_response(400)

      assert response["error"] == "message is required"
    end

    test "handles chat errors gracefully", %{conn: conn} do
      with_mock Chat, send_message: fn _msg, _session, _opts -> {:error, :llm_failed} end do
        response =
          conn
          |> post("/api/v1/chat", %{
            message: "Hello",
            session_id: "test-session"
          })
          |> json_response(500)

        assert String.contains?(response["error"], "llm_failed")
      end
    end

    test "generates default session_id when not provided", %{conn: conn} do
      with_mock Chat,
        send_message: fn _msg, session_id, _opts ->
          {:ok,
           %{
             response: "Hello!",
             session: session_id,
             context_used: 0,
             history_included: 0
           }}
        end do
        response =
          conn
          |> post("/api/v1/chat", %{message: "Hello"})
          |> json_response(200)

        assert String.starts_with?(response["session_id"], "api-session-")
      end
    end
  end

  describe "GET /api/v1/chat/:session_id" do
    test "returns chat history for existing session", %{conn: conn, session: session} do
      # Insert some test messages
      %Obelisk.Schemas.Message{
        role: :user,
        content: %{text: "Hello"},
        session_id: session.id
      }
      |> Obelisk.Repo.insert!()

      %Obelisk.Schemas.Message{
        role: :assistant,
        content: %{text: "Hi there!"},
        session_id: session.id
      }
      |> Obelisk.Repo.insert!()

      response =
        conn
        |> get("/api/v1/chat/#{session.name}")
        |> json_response(200)

      assert response["session_id"] == session.name
      assert length(response["messages"]) == 2

      messages = response["messages"]
      assert Enum.any?(messages, fn msg -> msg["role"] == "user" end)
      assert Enum.any?(messages, fn msg -> msg["role"] == "assistant" end)
    end

    test "returns error for non-existent session", %{conn: conn} do
      with_mock Memory, get_or_create_session: fn _ -> {:error, :not_found} end do
        response =
          conn
          |> get("/api/v1/chat/non-existent")
          |> json_response(404)

        assert String.contains?(response["error"], "Session not found")
      end
    end
  end
end
