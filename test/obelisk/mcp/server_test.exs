defmodule Obelisk.MCP.ServerTest do
  use ExUnit.Case, async: true
  import Mock

  alias Obelisk.MCP.Server

  setup do
    # Try to start the server, handle case where it's already started
    case Server.start_link() do
      {:ok, pid} ->
        on_exit(fn -> GenServer.cast(pid, :stop) end)
        {:ok, server: pid}

      {:error, {:already_started, pid}} ->
        {:ok, server: pid}
    end
  end

  describe "JSON-RPC message handling" do
    test "handles tools/list request" do
      request = %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "tools/list"
      }

      {:ok, response} = GenServer.call(Server, {:process_request, request})

      assert response.jsonrpc == "2.0"
      assert response.id == 1
      assert Map.has_key?(response, :result)
      assert is_list(response.result.tools)

      # Verify tools have required fields
      tools = response.result.tools

      Enum.each(tools, fn tool ->
        assert Map.has_key?(tool, :name)
        assert Map.has_key?(tool, :description)
        assert Map.has_key?(tool, :inputSchema)
      end)
    end

    test "handles tools/call request successfully" do
      request = %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "tools/call",
        "params" => %{
          "name" => "echo",
          "arguments" => %{"message" => "test"}
        }
      }

      {:ok, response} = GenServer.call(Server, {:process_request, request})

      assert response.jsonrpc == "2.0"
      assert response.id == 2
      assert Map.has_key?(response, :result)
      assert response.result.success == true
      assert response.result.echoed_message == "test"
    end

    test "handles tools/call with invalid tool name" do
      request = %{
        "jsonrpc" => "2.0",
        "id" => 3,
        "method" => "tools/call",
        "params" => %{
          "name" => "nonexistent",
          "arguments" => %{}
        }
      }

      {:error, response} = GenServer.call(Server, {:process_request, request})

      assert response.jsonrpc == "2.0"
      assert response.id == 3
      assert Map.has_key?(response, :error)
      assert response.error.code == -32602
      assert response.error.message == "Tool execution failed"
    end

    test "handles ping request" do
      request = %{
        "jsonrpc" => "2.0",
        "id" => 4,
        "method" => "ping"
      }

      {:ok, response} = GenServer.call(Server, {:process_request, request})

      assert response.jsonrpc == "2.0"
      assert response.id == 4
      assert response.result.status == "ok"
      assert response.result.server == "obelisk-mcp"
      assert Map.has_key?(response.result, :timestamp)
    end

    test "handles unknown method" do
      request = %{
        "jsonrpc" => "2.0",
        "id" => 5,
        "method" => "unknown/method"
      }

      {:error, response} = GenServer.call(Server, {:process_request, request})

      assert response.jsonrpc == "2.0"
      assert response.id == 5
      assert response.error.code == -32601
      assert response.error.message == "Method not found"
    end

    test "handles invalid request format" do
      request = %{"invalid" => "request"}

      {:error, response} = GenServer.call(Server, {:process_request, request})

      assert response.jsonrpc == "2.0"
      assert response.id == nil
      assert response.error.code == -32600
      assert response.error.message == "Invalid Request"
    end

    test "handles tools/call with missing parameters" do
      request = %{
        "jsonrpc" => "2.0",
        "id" => 6,
        "method" => "tools/call",
        "params" => %{"arguments" => %{}}
      }

      {:error, response} = GenServer.call(Server, {:process_request, request})

      assert response.jsonrpc == "2.0"
      assert response.id == 6
      assert response.error.code == -32602
      assert response.error.data.reason =~ "Missing or invalid tool name"
    end
  end

  describe "server lifecycle" do
    test "starts and stops GenServer" do
      # Start a new server with a different name to avoid conflicts
      {:ok, pid} = Server.start_link(name: :test_server)
      assert Process.alive?(pid)

      GenServer.cast(pid, :stop)
      # Give it time to stop
      :timer.sleep(10)
      refute Process.alive?(pid)
    end
  end

  describe "tool execution integration" do
    test "executes memory search tool through MCP" do
      mock_results = [
        %{
          id: 1,
          text: "test result",
          kind: :fact,
          score: 0.9,
          session_id: "test",
          inserted_at: ~N[2025-01-01 12:00:00]
        }
      ]

      with_mock Obelisk.Retrieval, retrieve: fn _q, _s, _k, _opts -> mock_results end do
        request = %{
          "jsonrpc" => "2.0",
          "id" => 7,
          "method" => "tools/call",
          "params" => %{
            "name" => "memory_search",
            "arguments" => %{"query" => "test search"}
          }
        }

        {:ok, response} = GenServer.call(Server, {:process_request, request})

        assert response.result.success == true
        assert response.result.query == "test search"
        assert length(response.result.results) == 1
      end
    end
  end
end
