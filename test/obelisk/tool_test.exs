defmodule Obelisk.ToolTest do
  use ExUnit.Case, async: true

  alias Obelisk.Tool

  defmodule TestTool do
    @behaviour Obelisk.Tool

    @impl true
    def spec do
      %{
        name: "test_tool",
        description: "A test tool for validation",
        params: %{
          type: "object",
          properties: %{
            message: %{type: "string", description: "Test message"},
            count: %{type: "integer", description: "Test count"}
          },
          required: ["message"]
        }
      }
    end

    @impl true
    def call(%{"message" => message}, _ctx) do
      {:ok, %{response: "Hello, #{message}!"}}
    end
  end

  describe "validate_params/2" do
    test "validates correct parameters" do
      params = %{"message" => "test"}
      assert {:ok, ^params} = Tool.validate_params(TestTool, params)
    end

    test "rejects missing required parameters" do
      params = %{"count" => 42}
      assert {:error, {:validation_error, _}} = Tool.validate_params(TestTool, params)
    end

    test "validates parameter types" do
      params = %{"message" => "test", "count" => "not_a_number"}
      assert {:error, {:validation_error, _}} = Tool.validate_params(TestTool, params)
    end

    test "allows extra parameters" do
      params = %{"message" => "test", "extra" => "value"}
      assert {:ok, ^params} = Tool.validate_params(TestTool, params)
    end
  end

  describe "error_response/2" do
    test "creates standardized error response" do
      response = Tool.error_response("test error")

      assert response.error == true
      assert response.reason == "test error"
      assert is_map(response.details)
      assert %DateTime{} = response.timestamp
    end

    test "formats different error types" do
      response1 = Tool.error_response(:validation_error)
      assert response1.reason == "validation_error"

      response2 = Tool.error_response({:validation_error, "invalid field"})
      assert response2.reason == "Validation error: invalid field"

      response3 = Tool.error_response({:tool_error, "failed"})
      assert response3.reason == "Tool error: failed"
    end
  end

  describe "success_response/1" do
    test "creates standardized success response" do
      data = %{result: "test"}
      response = Tool.success_response(data)

      assert response.success == true
      assert response.result == "test"
      assert %DateTime{} = response.timestamp
    end
  end
end
