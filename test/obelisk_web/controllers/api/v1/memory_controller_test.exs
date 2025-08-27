defmodule ObeliskWeb.Api.V1.MemoryControllerTest do
  use ObeliskWeb.ConnCase
  import Mock

  alias Obelisk.{Memory, Retrieval}

  describe "POST /api/v1/memory/search" do
    test "searches memories successfully", %{conn: conn} do
      mock_results = [
        %{
          id: 1,
          text: "Elixir is a functional language",
          score: 0.95,
          memory_id: 1,
          kind: :fact,
          session_id: nil
        }
      ]

      with_mock Retrieval, retrieve: fn _query, _session_id, _k, _opts -> mock_results end do
        response =
          conn
          |> post("/api/v1/memory/search", %{
            query: "What is Elixir?",
            k: 5
          })
          |> json_response(200)

        assert response["query"] == "What is Elixir?"
        assert length(response["results"]) == 1
        assert response["count"] == 1

        result = hd(response["results"])
        assert result["text"] == "Elixir is a functional language"
        assert result["score"] == 0.95
      end
    end

    test "returns error for missing query", %{conn: conn} do
      response =
        conn
        |> post("/api/v1/memory/search", %{k: 5})
        |> json_response(400)

      assert response["error"] == "query is required"
    end

    test "handles search errors", %{conn: conn} do
      with_mock Retrieval,
        retrieve: fn _query, _session_id, _k, _opts -> {:error, :search_failed} end do
        response =
          conn
          |> post("/api/v1/memory/search", %{query: "test"})
          |> json_response(500)

        assert String.contains?(response["error"], "Search failed")
      end
    end
  end

  describe "POST /api/v1/memory" do
    test "creates memory successfully", %{conn: conn} do
      mock_memory = %{
        id: 1,
        text: "Phoenix is a web framework",
        kind: :fact,
        metadata: %{},
        session_id: nil,
        embedding: [0.1, 0.2],
        inserted_at: ~N[2025-01-01 00:00:00]
      }

      with_mock Memory, store_memory_simple: fn _attrs -> {:ok, mock_memory} end do
        response =
          conn
          |> post("/api/v1/memory", %{
            text: "Phoenix is a web framework",
            kind: "fact"
          })
          |> json_response(201)

        assert response["id"] == 1
        assert response["text"] == "Phoenix is a web framework"
        assert response["kind"] == "fact"
        assert response["has_embedding"] == true
      end
    end

    test "returns error for missing text", %{conn: conn} do
      response =
        conn
        |> post("/api/v1/memory", %{kind: "fact"})
        |> json_response(400)

      assert response["error"] == "text is required"
    end

    test "handles validation errors", %{conn: conn} do
      changeset_error = %Ecto.Changeset{
        errors: [text: {"can't be blank", []}],
        valid?: false
      }

      with_mock Memory, store_memory_simple: fn _attrs -> {:error, changeset_error} end do
        response =
          conn
          |> post("/api/v1/memory", %{text: "test"})
          |> json_response(422)

        assert response["error"] == "Validation failed"
        assert Map.has_key?(response, "details")
      end
    end
  end

  describe "GET /api/v1/memory" do
    test "lists memories successfully", %{conn: conn} do
      mock_memories = [
        %{
          id: 1,
          text: "First memory",
          kind: :note,
          metadata: %{},
          session_id: nil,
          embedding: nil,
          inserted_at: ~N[2025-01-01 00:00:00]
        },
        %{
          id: 2,
          text: "Second memory",
          kind: :fact,
          metadata: %{source: "api"},
          session_id: 1,
          embedding: [0.1, 0.2],
          inserted_at: ~N[2025-01-01 00:01:00]
        }
      ]

      with_mocks([
        {Memory, [], [list_memories: fn _session_id -> mock_memories end]},
        {Memory, [], [get_or_create_session: fn _name -> {:ok, %{id: 1}} end]}
      ]) do
        response =
          conn
          |> get("/api/v1/memory")
          |> json_response(200)

        assert response["count"] == 2
        assert length(response["memories"]) == 2

        memories = response["memories"]
        assert Enum.any?(memories, fn m -> m["text"] == "First memory" end)
        assert Enum.any?(memories, fn m -> m["text"] == "Second memory" end)
      end
    end

    test "respects limit parameter", %{conn: conn} do
      mock_memories =
        Enum.map(1..10, fn i ->
          %{
            id: i,
            text: "Memory #{i}",
            kind: :note,
            metadata: %{},
            session_id: nil,
            embedding: nil,
            inserted_at: ~N[2025-01-01 00:00:00]
          }
        end)

      with_mock Memory, list_memories: fn _session_id -> mock_memories end do
        response =
          conn
          |> get("/api/v1/memory?limit=5")
          |> json_response(200)

        assert response["count"] == 5
        assert length(response["memories"]) == 5
      end
    end
  end
end
