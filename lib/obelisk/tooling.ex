defmodule Obelisk.Tooling do
  @moduledoc """
  Central registry and execution engine for Obelisk tools.

  This module manages the catalog of available tools, handles tool discovery,
  validation, and execution. Tools are automatically registered and can be
  called via the MCP server or directly through this module.

  ## Tool Registration

  Tools are registered by adding them to the `@tools` module attribute:

      @tools [
        Obelisk.Tools.Echo,
        Obelisk.Tools.Memory,
        Obelisk.Tools.Chat
      ]

  ## Usage

      # List all available tools
      tools = Obelisk.Tooling.catalog()

      # Call a specific tool
      {:ok, result} = Obelisk.Tooling.call("echo", %{"message" => "hello"}, %{})

  """

  require Logger

  # Registry of available tools
  @tools [
    Obelisk.Tools.Echo,
    Obelisk.Tools.Memory,
    Obelisk.Tools.Chat
  ]

  @doc """
  Returns the catalog of all available tools with their specifications.

  ## Returns
  List of tool specifications including:
  - `name` - Tool identifier
  - `description` - Human-readable description
  - `params` - JSON Schema for parameters
  """
  def catalog do
    @tools
    |> Enum.map(fn tool_module ->
      try do
        spec = tool_module.spec()
        Map.put(spec, :module, tool_module)
      rescue
        error ->
          Logger.error("Failed to load tool spec for #{inspect(tool_module)}: #{inspect(error)}")
          nil
      end
    end)
    |> Enum.filter(& &1)
  end

  @doc """
  Returns the specification for a specific tool by name.

  ## Parameters
  - `name` - Tool name to look up

  ## Returns
  - `{:ok, spec}` - Tool specification found
  - `{:error, :not_found}` - Tool not found
  """
  def get_tool_spec(name) when is_binary(name) do
    case find_tool_module(name) do
      {:ok, module} ->
        {:ok, module.spec()}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Executes a tool with the given parameters and context.

  ## Parameters
  - `name` - Tool name to execute
  - `params` - Parameters map for the tool
  - `ctx` - Execution context (session_id, user, etc.)

  ## Returns
  - `{:ok, result}` - Successful execution
  - `{:error, reason}` - Execution failed

  ## Example

      ctx = %{
        session_id: "my-session",
        user: "alice",
        request_id: "req-123"
      }

      {:ok, result} = Obelisk.Tooling.call("echo", %{"message" => "hello"}, ctx)

  """
  def call(name, params, ctx \\ %{}) when is_binary(name) and is_map(params) and is_map(ctx) do
    Logger.info("Executing tool: #{name} with params: #{inspect(params)}")

    with {:ok, module} <- find_tool_module(name),
         {:ok, validated_params} <- Obelisk.Tool.validate_params(module, params),
         enriched_ctx <- enrich_context(ctx),
         {:ok, result} <- execute_tool(module, validated_params, enriched_ctx) do
      Logger.info("Tool #{name} executed successfully")
      {:ok, Obelisk.Tool.success_response(result)}
    else
      {:error, :not_found} ->
        Logger.warning("Tool not found: #{name}")
        {:error, Obelisk.Tool.error_response("Tool not found: #{name}")}

      {:error, reason} ->
        Logger.error("Tool execution failed for #{name}: #{inspect(reason)}")
        {:error, Obelisk.Tool.error_response(reason)}
    end
  end

  @doc """
  Returns a list of tool names that are currently available.
  """
  def list_tool_names do
    catalog()
    |> Enum.map(fn spec -> spec.name end)
    |> Enum.sort()
  end

  @doc """
  Checks if a tool with the given name exists.
  """
  def tool_exists?(name) when is_binary(name) do
    case find_tool_module(name) do
      {:ok, _module} -> true
      {:error, :not_found} -> false
    end
  end

  @doc """
  Returns information about the tooling system for debugging.
  """
  def system_info do
    tools = catalog()

    %{
      total_tools: length(tools),
      tool_names: list_tool_names(),
      registry: @tools,
      loaded_at: DateTime.utc_now(),
      version: Application.spec(:obelisk, :vsn) || "dev"
    }
  end

  # Private functions

  defp find_tool_module(name) do
    found_tool =
      @tools
      |> Enum.find(fn module ->
        try do
          spec = module.spec()
          spec.name == name
        rescue
          _ -> false
        end
      end)

    case found_tool do
      nil -> {:error, :not_found}
      module -> {:ok, module}
    end
  end

  defp execute_tool(module, params, ctx) do
    try do
      case module.call(params, ctx) do
        {:ok, result} when is_map(result) ->
          {:ok, result}

        {:ok, result} ->
          {:ok, %{data: result}}

        {:error, reason} ->
          {:error, {:tool_error, reason}}

        other ->
          {:error, {:tool_error, "Invalid tool response: #{inspect(other)}"}}
      end
    rescue
      error ->
        {:error, {:tool_error, "Tool crashed: #{inspect(error)}"}}
    catch
      :exit, reason ->
        {:error, {:tool_error, "Tool exited: #{inspect(reason)}"}}

      kind, payload ->
        {:error, {:tool_error, "Tool threw #{kind}: #{inspect(payload)}"}}
    end
  end

  defp enrich_context(ctx) do
    ctx
    |> Map.put_new(:timestamp, DateTime.utc_now())
    |> Map.put_new(:request_id, generate_request_id())
    |> Map.put_new(:session_id, "default")
  end

  defp generate_request_id do
    :crypto.strong_rand_bytes(8)
    |> Base.encode16(case: :lower)
  end
end
