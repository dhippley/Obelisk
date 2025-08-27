defmodule Obelisk.Tools.MemoryTest do
  use ExUnit.Case, async: true
  import Mock

  alias Obelisk.Tools.Memory

  describe "spec/0" do
    test "returns valid tool specification" do
      spec = Memory.spec()

      assert spec.name == "memory_search"
      assert is_binary(spec.description)
      assert spec.description =~ "Search through stored memories"

      # Validate parameter schema
      assert spec.params.type == "object"
      assert spec.params.required == ["query"]

      properties = spec.params.properties
      assert properties.query.type == "string"
      assert properties.k.type == "integer"
      assert properties.k.minimum == 1
      assert properties.k.maximum == 50
    end
  end

  describe "call/2" do
    test "searches memories successfully" do
      mock_results = [
        %{
          id: 1,
          text: "Test memory content",
          kind: :fact,
          score: 0.95,
          session_id: "session-1",
          inserted_at: ~N[2025-01-01 12:00:00]
        }
      ]

      with_mock Obelisk.Retrieval,
        retrieve: fn _query, _session_id, _k, _opts ->
          mock_results
        end do
        params = %{"query" => "test query", "k" => 5}
        ctx = %{session_id: "test-session"}

        {:ok, result} = Memory.call(params, ctx)

        assert result.query == "test query"
        assert result.total_found == 1
        assert length(result.results) == 1

        memory = hd(result.results)
        assert memory.id == 1
        assert memory.text == "Test memory content"
        assert memory.kind == :fact
        assert memory.score == 0.95

        assert result.search_params.k == 5
        assert result.search_params.session_id == "test-session"
        assert result.search_params.threshold == 0.7
      end
    end

    test "uses custom parameters" do
      with_mock Obelisk.Retrieval,
        retrieve: fn query, session_id, k, opts ->
          assert query == "custom query"
          assert session_id == "custom-session"
          assert k == 10
          assert opts.threshold == 0.8
          []
        end do
        params = %{
          "query" => "custom query",
          "k" => 10,
          "session_id" => "custom-session",
          "threshold" => 0.8
        }

        ctx = %{}

        Memory.call(params, ctx)
      end
    end

    test "uses context session_id when not provided in params" do
      with_mock Obelisk.Retrieval,
        retrieve: fn _query, session_id, _k, _opts ->
          assert session_id == "context-session"
          []
        end do
        params = %{"query" => "test"}
        ctx = %{session_id: "context-session"}

        Memory.call(params, ctx)
      end
    end

    test "handles retrieval errors" do
      with_mock Obelisk.Retrieval,
        retrieve: fn _query, _session_id, _k, _opts ->
          raise "Database error"
        end do
        params = %{"query" => "test"}
        ctx = %{}

        {:error, error_message} = Memory.call(params, ctx)
        assert error_message =~ "Memory search failed"
      end
    end

    test "uses default parameters when not specified" do
      with_mock Obelisk.Retrieval,
        retrieve: fn _query, _session_id, k, opts ->
          # default k
          assert k == 5
          # default threshold
          assert opts.threshold == 0.7
          []
        end do
        params = %{"query" => "test"}
        ctx = %{session_id: "test"}

        Memory.call(params, ctx)
      end
    end
  end
end
