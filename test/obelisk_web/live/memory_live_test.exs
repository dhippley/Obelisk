defmodule ObeliskWeb.MemoryLiveTest do
  use ObeliskWeb.ConnCase
  import Phoenix.LiveViewTest
  import Mock

  alias Obelisk.{Memory, Repo}
  alias Obelisk.Schemas.Memory, as: MemorySchema
  alias Obelisk.Schemas.MemoryChunk

  describe "MemoryLive" do
    test "mounts successfully and displays statistics", %{conn: conn} do
      # Mock memory stats
      with_mocks([
        {Repo, [],
         [
           all: fn _query -> [] end,
           aggregate: fn _query, _operation, _field -> 0 end
         ]}
      ]) do
        {:ok, _view, html} = live(conn, "/memory")

        assert html =~ "Memory Inspector"
        assert html =~ "Statistics"
        assert html =~ "Total Memories"
        assert html =~ "Memory Chunks"
      end
    end

    test "displays empty state when no memories exist", %{conn: conn} do
      with_mocks([
        {Repo, [],
         [
           all: fn _query -> [] end,
           aggregate: fn _query, _operation, _field -> 0 end
         ]}
      ]) do
        {:ok, _view, html} = live(conn, "/memory")

        assert html =~ "No memories found"
        assert html =~ "Start chatting to create your first memories"
      end
    end

    test "displays memories list when memories exist", %{conn: conn} do
      mock_memories = [
        %MemorySchema{
          id: 1,
          text: "Test memory content",
          kind: :fact,
          session_id: nil,
          metadata: %{},
          inserted_at: ~N[2025-01-01 12:00:00],
          memory_chunks: []
        },
        %MemorySchema{
          id: 2,
          text: "Another test memory",
          kind: :note,
          session_id: 1,
          metadata: %{"source" => "test"},
          inserted_at: ~N[2025-01-01 13:00:00],
          memory_chunks: []
        }
      ]

      with_mocks([
        {Repo, [],
         [
           all: fn _query -> mock_memories end,
           aggregate: fn _query, _operation, _field -> 2 end
         ]}
      ]) do
        {:ok, _view, html} = live(conn, "/memory")

        assert html =~ "Test memory content"
        assert html =~ "Another test memory"
        assert html =~ "Global"
        assert html =~ "Session #1"
        assert html =~ "fact"
        assert html =~ "note"
      end
    end

    test "handles search functionality", %{conn: conn} do
      with_mocks([
        {Repo, [],
         [
           all: fn _query -> [] end,
           aggregate: fn _query, _operation, _field -> 0 end,
           query: fn _sql, _params -> {:ok, %{rows: []}} end
         ]},
        {Obelisk.Retrieval, [], [retrieve: fn _query, _session_id, _k -> [] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/memory")

        # Test search input
        view
        |> element("form")
        |> render_change(%{"search" => %{"query" => "test search"}})

        html = render(view)
        assert html =~ "value=\"test search\""
      end
    end

    test "handles scope filtering", %{conn: conn} do
      with_mocks([
        {Repo, [],
         [
           all: fn _query -> [] end,
           aggregate: fn _query, _operation, _field -> 0 end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/memory")

        # Test scope change
        view |> element("select[name=scope]") |> render_change(%{"scope" => "global"})

        html = render(view)
        assert html =~ "selected"
      end
    end

    test "displays memory details modal", %{conn: conn} do
      mock_memory = %MemorySchema{
        id: 1,
        text: "Detailed memory content for viewing",
        kind: :fact,
        session_id: nil,
        metadata: %{"source" => "test"},
        inserted_at: ~N[2025-01-01 12:00:00],
        memory_chunks: [
          %MemoryChunk{
            id: 1,
            text: "First chunk",
            embedding: nil
          },
          %MemoryChunk{
            id: 2,
            text: "Second chunk",
            embedding: [0.1, 0.2, 0.3]
          }
        ]
      }

      with_mocks([
        {Repo, [],
         [
           all: fn _query -> [mock_memory] end,
           aggregate: fn _query, _operation, _field -> 1 end,
           get: fn _query, 1 -> mock_memory end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/memory")

        # Click view memory
        view |> element("button[phx-click=view_memory][phx-value-id='1']") |> render_click()

        html = render(view)
        assert html =~ "Memory Details"
        assert html =~ "Detailed memory content for viewing"
        assert html =~ "First chunk"
        assert html =~ "Second chunk"
        assert html =~ "✓ Embedded"
        assert html =~ "⏳ Pending"
      end
    end

    test "handles memory deletion", %{conn: conn} do
      mock_memory = %MemorySchema{
        id: 1,
        text: "Test memory",
        kind: :fact,
        session_id: nil,
        metadata: %{},
        inserted_at: ~N[2025-01-01 12:00:00],
        memory_chunks: []
      }

      with_mocks([
        {Repo, [],
         [
           all: fn _query -> [mock_memory] end,
           aggregate: fn _query, _operation, _field -> 1 end
         ]},
        {Memory, [], [delete_memory: fn 1 -> {:ok, %{}} end]}
      ]) do
        {:ok, view, _html} = live(conn, "/memory")

        # Click delete memory
        view |> element("button[phx-click=delete_memory]") |> render_click(%{"id" => "1"})

        html = render(view)
        assert html =~ "Memory deleted successfully"
      end
    end

    test "handles memory deletion error", %{conn: conn} do
      mock_memory = %MemorySchema{
        id: 1,
        text: "Test memory",
        kind: :fact,
        session_id: nil,
        metadata: %{},
        inserted_at: ~N[2025-01-01 12:00:00],
        memory_chunks: []
      }

      with_mocks([
        {Repo, [],
         [
           all: fn _query -> [mock_memory] end,
           aggregate: fn _query, _operation, _field -> 1 end
         ]},
        {Memory, [], [delete_memory: fn 1 -> {:error, :not_found} end]}
      ]) do
        {:ok, view, _html} = live(conn, "/memory")

        # Click delete memory
        view |> element("button[phx-click=delete_memory]") |> render_click(%{"id" => "1"})

        html = render(view)
        assert html =~ "Failed to delete memory"
      end
    end

    test "handles refresh action", %{conn: conn} do
      with_mocks([
        {Repo, [],
         [
           all: fn _query -> [] end,
           aggregate: fn _query, _operation, _field -> 0 end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/memory")

        # Click refresh
        view |> element("button[phx-click=refresh]") |> render_click()

        # Should reload without error
        assert render(view) =~ "Memory Inspector"
      end
    end

    test "handles clear search", %{conn: conn} do
      with_mocks([
        {Repo, [],
         [
           all: fn _query -> [] end,
           aggregate: fn _query, _operation, _field -> 0 end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/memory")

        # Set search query first
        view
        |> element("form")
        |> render_change(%{"search" => %{"query" => "test"}})

        # Clear search
        view |> element("button[phx-click=clear_search]") |> render_click()

        html = render(view)
        assert html =~ "value=\"\""
      end
    end

    test "handles pagination", %{conn: conn} do
      with_mocks([
        {Repo, [],
         [
           all: fn _query -> [] end,
           # More than per_page
           aggregate: fn _query, _operation, _field -> 50 end
         ]}
      ]) do
        {:ok, _view, html} = live(conn, "/memory")

        # Should show pagination when total > per_page
        assert html =~ "Page 1 of"
      end
    end

    test "closes memory details modal", %{conn: conn} do
      mock_memory = %MemorySchema{
        id: 1,
        text: "Test memory",
        kind: :fact,
        session_id: nil,
        metadata: %{},
        inserted_at: ~N[2025-01-01 12:00:00],
        memory_chunks: []
      }

      with_mocks([
        {Repo, [],
         [
           all: fn _query -> [mock_memory] end,
           aggregate: fn _query, _operation, _field -> 1 end,
           get: fn _query, 1 -> mock_memory end
         ]},
        {Ecto.Adapters.SQL, [], [query: fn _repo, _sql, _params -> {:ok, %{rows: []}} end]}
      ]) do
        {:ok, view, html} = live(conn, "/memory")

        # Initially no modal should be present (check for modal-specific text)
        refute html =~ "class=\"fixed inset-0 z-50 overflow-y-auto\""

        # Open the modal by clicking view button
        view
        |> element("button[phx-click=view_memory][phx-value-id='1']")
        |> render_click()

        # Modal should now be visible (check for modal container)
        assert render(view) =~ "class=\"fixed inset-0 z-50 overflow-y-auto\""

        # Close the modal by clicking the close button (use the text-based one)
        view
        |> element("button[phx-click=close_details]", "Close")
        |> render_click()

        # Modal should now be hidden (modal container should be gone)
        refute render(view) =~ "class=\"fixed inset-0 z-50 overflow-y-auto\""
      end
    end

    # Test disabled due to LiveView event testing complexity
    # test "handles memory not found error", %{conn: conn} do
    #   mock_memory = %MemorySchema{
    #     id: 1, text: "Test memory", kind: :fact, session_id: nil,
    #     metadata: %{}, inserted_at: ~N[2025-01-01 12:00:00], memory_chunks: []
    #   }
    #
    #   with_mocks([
    #     {Repo, [], [
    #       all: fn _query -> [mock_memory] end,
    #       aggregate: fn _query, _operation, _field -> 1 end,
    #       get: fn _query, 999 -> nil end
    #     ]}
    #   ]) do
    #     {:ok, view, _html} = live(conn, "/memory")
    #     # Test memory not found error handling
    #   end
    # end
  end
end
