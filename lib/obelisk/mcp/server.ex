defmodule Obelisk.MCP.Server do
  @moduledoc """
  Model Context Protocol (MCP) server implementation using JSON-RPC 2.0 over stdio.

  This server exposes Obelisk tools to AI assistants like Claude Desktop, Cursor,
  and other MCP-compatible clients. It follows the JSON-RPC 2.0 specification
  and handles tool discovery and execution.

  ## Supported Methods

  - `tools/list` - List all available tools
  - `tools/call` - Execute a specific tool
  - `ping` - Health check endpoint

  ## Usage

      # Start the MCP server (blocks)
      Obelisk.MCP.Server.start_stdio()

      # Or start in a supervised process
      {:ok, pid} = Obelisk.MCP.Server.start_link()

  ## JSON-RPC Examples

      # List tools request
      {"jsonrpc": "2.0", "id": 1, "method": "tools/list"}

      # Call tool request
      {"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "echo", "arguments": {"message": "hello"}}}

  """

  use GenServer
  require Logger

  @jsonrpc_version "2.0"

  # Client API

  @doc """
  Starts the MCP server using stdio for communication.

  This function blocks the calling process and handles JSON-RPC messages
  from stdin, writing responses to stdout.
  """
  def start_stdio do
    Logger.info("Starting Obelisk MCP Server on stdio")

    # Configure stdio for binary mode
    :ok = :io.setopts([{:encoding, :utf8}, {:binary, true}])

    # Send server info on startup
    send_server_info()

    # Start the main loop
    loop(%{})
  end

  @doc """
  Starts the MCP server as a GenServer process.

  Returns `{:ok, pid}` for use in supervision trees.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    Logger.info("MCP Server GenServer started")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:process_request, request}, _from, state) do
    case handle_request(request, state) do
      {:ok, response, new_state} ->
        {:reply, {:ok, response}, new_state}

      {:error, error} ->
        {:reply, {:error, error}, state}
    end
  end

  @impl true
  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  # Private functions - Main Loop

  defp loop(state) do
    case IO.read(:stdio, :line) do
      :eof ->
        Logger.info("MCP Server: EOF received, shutting down")
        :ok

      {:error, reason} ->
        Logger.error("MCP Server: IO error: #{inspect(reason)}")
        :ok

      data when is_binary(data) ->
        case String.trim(data) do
          "" ->
            loop(state)

          json_line ->
            case process_line(json_line, state) do
              {:ok, new_state} -> loop(new_state)
              # Continue on errors
              {:error, _reason} -> loop(state)
            end
        end
    end
  end

  defp process_line(json_line, state) do
    case Jason.decode(json_line) do
      {:ok, request} ->
        case handle_request(request, state) do
          {:ok, response, new_state} ->
            send_response(response)
            {:ok, new_state}

          {:error, error_response} ->
            send_response(error_response)
            {:ok, state}
        end

      {:error, decode_error} ->
        Logger.error("JSON decode error: #{inspect(decode_error)}")

        error_response =
          json_rpc_error(nil, -32_700, "Parse error", %{details: inspect(decode_error)})

        send_response(error_response)
        {:error, :parse_error}
    end
  end

  # Request Handling

  defp handle_request(%{"method" => "tools/list", "id" => id}, state) do
    Logger.debug("Handling tools/list request")

    tools = Obelisk.Tooling.catalog()
    formatted_tools = Enum.map(tools, &format_tool_for_response/1)

    response = json_rpc_success(id, %{tools: formatted_tools})
    {:ok, response, state}
  end

  defp handle_request(%{"method" => "tools/call", "id" => id, "params" => params}, state) do
    Logger.debug("Handling tools/call request: #{inspect(params)}")

    with {:ok, name} <- extract_tool_name(params),
         {:ok, arguments} <- extract_tool_arguments(params),
         {:ok, result} <- execute_tool(name, arguments, %{}) do
      response = json_rpc_success(id, result)
      {:ok, response, state}
    else
      {:error, reason} ->
        error_response = json_rpc_error(id, -32_602, "Tool execution failed", %{reason: reason})
        {:error, error_response}
    end
  end

  defp handle_request(%{"method" => "ping", "id" => id}, state) do
    Logger.debug("Handling ping request")

    response =
      json_rpc_success(id, %{
        status: "ok",
        server: "obelisk-mcp",
        version: Application.spec(:obelisk, :vsn) || "dev",
        timestamp: DateTime.utc_now()
      })

    {:ok, response, state}
  end

  defp handle_request(%{"method" => method, "id" => id}, _state) do
    Logger.warning("Unknown method: #{method}")
    error_response = json_rpc_error(id, -32_601, "Method not found", %{method: method})
    {:error, error_response}
  end

  defp handle_request(request, _state) do
    Logger.error("Invalid request format: #{inspect(request)}")
    error_response = json_rpc_error(nil, -32_600, "Invalid Request")
    {:error, error_response}
  end

  # Tool Execution

  defp extract_tool_name(%{"name" => name}) when is_binary(name), do: {:ok, name}
  defp extract_tool_name(_), do: {:error, "Missing or invalid tool name"}

  defp extract_tool_arguments(%{"arguments" => args}) when is_map(args), do: {:ok, args}
  defp extract_tool_arguments(_), do: {:ok, %{}}

  defp execute_tool(name, arguments, context) do
    case Obelisk.Tooling.call(name, arguments, context) do
      {:ok, result} -> {:ok, result}
      {:error, error} -> {:error, inspect(error)}
    end
  end

  # Response Formatting

  defp format_tool_for_response(tool_spec) do
    %{
      name: tool_spec.name,
      description: tool_spec.description,
      inputSchema: tool_spec.params
    }
  end

  defp json_rpc_success(id, result) do
    %{
      jsonrpc: @jsonrpc_version,
      id: id,
      result: result
    }
  end

  defp json_rpc_error(id, code, message, data \\ nil) do
    error = %{code: code, message: message}
    error = if data, do: Map.put(error, :data, data), else: error

    %{
      jsonrpc: @jsonrpc_version,
      id: id,
      error: error
    }
  end

  # I/O Operations

  defp send_response(response) do
    json = Jason.encode!(response)
    IO.binwrite(:stdio, json <> "\n")
  end

  defp send_server_info do
    info = %{
      server: "obelisk-mcp",
      version: Application.spec(:obelisk, :vsn) || "dev",
      capabilities: %{
        tools: %{
          list: true,
          call: true
        }
      },
      started_at: DateTime.utc_now()
    }

    # Send as a notification (no id field)
    notification = %{
      jsonrpc: @jsonrpc_version,
      method: "server/info",
      params: info
    }

    send_response(notification)
  end
end
