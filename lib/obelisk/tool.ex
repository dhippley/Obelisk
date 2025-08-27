defmodule Obelisk.Tool do
  @moduledoc """
  Behaviour for defining tools that can be called by AI agents.

  Tools are exposed via the MCP (Model Context Protocol) server and can be invoked
  by AI assistants to perform specific actions like searching memory, making API calls,
  or interacting with the filesystem.

  ## Example Tool Implementation

      defmodule MyApp.Tools.Calculator do
        @behaviour Obelisk.Tool

        @impl true
        def spec do
          %{
            name: "calculator",
            description: "Perform basic arithmetic operations",
            params: %{
              type: "object",
              properties: %{
                operation: %{
                  type: "string",
                  enum: ["add", "subtract", "multiply", "divide"],
                  description: "The arithmetic operation to perform"
                },
                a: %{type: "number", description: "First number"},
                b: %{type: "number", description: "Second number"}
              },
              required: ["operation", "a", "b"]
            }
          }
        end

        @impl true
        def call(%{"operation" => "add", "a" => a, "b" => b}, _ctx) do
          {:ok, %{result: a + b}}
        end

        def call(%{"operation" => "subtract", "a" => a, "b" => b}, _ctx) do
          {:ok, %{result: a - b}}
        end

        # ... other operations ...
      end

  ## Tool Context

  The context map passed to `call/2` contains useful information:
  - `:session_id` - Current session identifier
  - `:user` - User information (if available)
  - `:timestamp` - When the tool was called
  - `:request_id` - Unique request identifier for tracing
  """

  @doc """
  Returns the tool specification including name, description, and parameter schema.

  The specification should follow JSON Schema format for parameters to enable
  proper validation and documentation generation.

  ## Returns
  - `name` - Unique tool identifier (string)
  - `description` - Human-readable description of what the tool does
  - `params` - JSON Schema object describing the expected parameters
  """
  @callback spec() :: %{
              name: String.t(),
              description: String.t(),
              params: map()
            }

  @doc """
  Executes the tool with the given parameters and context.

  ## Parameters
  - `params` - Map of parameters validated against the tool's schema
  - `ctx` - Context map containing session info, user data, etc.

  ## Returns
  - `{:ok, result}` - Successful execution with result map
  - `{:error, reason}` - Execution failed with error reason
  """
  @callback call(params :: map(), ctx :: map()) :: {:ok, map()} | {:error, term()}

  @doc """
  Validates tool parameters against the tool's schema.
  """
  def validate_params(tool_module, params) when is_atom(tool_module) do
    spec = tool_module.spec()

    case validate_against_schema(params, spec.params) do
      :ok -> {:ok, params}
      {:error, reason} -> {:error, {:validation_error, reason}}
    end
  end

  @doc """
  Creates a standardized error response for tool execution.
  """
  def error_response(reason, details \\ %{}) do
    %{
      error: true,
      reason: format_error_reason(reason),
      details: details,
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Creates a standardized success response for tool execution.
  """
  def success_response(data) do
    Map.merge(data, %{
      success: true,
      timestamp: DateTime.utc_now()
    })
  end

  # Private helper functions

  defp validate_against_schema(params, schema) do
    # Basic validation - in production you'd want a proper JSON Schema validator
    case schema do
      %{type: "object", required: required, properties: properties} ->
        validate_object(params, required, properties)

      _ ->
        :ok
    end
  end

  defp validate_object(params, required, properties) when is_map(params) do
    # Check required fields
    missing = Enum.filter(required, fn key -> not Map.has_key?(params, key) end)

    if missing != [] do
      {:error, "Missing required fields: #{Enum.join(missing, ", ")}"}
    else
      # Validate field types (simplified)
      validate_properties(params, properties)
    end
  end

  defp validate_object(_params, _required, _properties) do
    {:error, "Parameters must be an object"}
  end

  defp validate_properties(params, properties) do
    # Validate each parameter that has a defined property
    invalid_fields =
      params
      |> Enum.filter(fn {key, value} ->
        validate_single_property(key, value, properties)
      end)
      |> Enum.map(fn {key, _value} -> key end)

    if invalid_fields != [] do
      {:error, "Invalid field types: #{Enum.join(invalid_fields, ", ")}"}
    else
      :ok
    end
  end

  defp validate_single_property(key, value, properties) do
    # Try both string and atom keys since params use strings but schema might use atoms
    try do
      atom_key = if is_binary(key), do: String.to_existing_atom(key), else: key
      property_def = Map.get(properties, atom_key) || Map.get(properties, key)

      case property_def do
        # Allow extra fields for now
        nil -> false
        %{type: type} -> not valid_type?(value, type)
        _ -> false
      end
    rescue
      ArgumentError ->
        # String.to_existing_atom failed, try string key only
        property_def = Map.get(properties, key)

        case property_def do
          nil -> false
          %{type: type} -> not valid_type?(value, type)
          _ -> false
        end
    end
  end

  defp valid_type?(value, "string") when is_binary(value), do: true
  defp valid_type?(value, "number") when is_number(value), do: true
  defp valid_type?(value, "integer") when is_integer(value), do: true
  defp valid_type?(value, "boolean") when is_boolean(value), do: true
  defp valid_type?(value, "array") when is_list(value), do: true
  defp valid_type?(value, "object") when is_map(value), do: true
  defp valid_type?(_value, _type), do: false

  defp format_error_reason(reason) when is_binary(reason), do: reason
  defp format_error_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_error_reason({:validation_error, details}), do: "Validation error: #{details}"
  defp format_error_reason({:tool_error, message}), do: "Tool error: #{message}"
  defp format_error_reason(reason), do: inspect(reason)
end
