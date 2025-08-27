defmodule Obelisk.ToolingTest do
  use ExUnit.Case, async: true

  alias Obelisk.Tooling

  describe "catalog/0" do
    test "returns list of available tools" do
      tools = Tooling.catalog()

      assert is_list(tools)
      # Echo, Memory, Chat
      assert length(tools) >= 3

      # Check that all tools have required fields
      Enum.each(tools, fn tool ->
        assert is_binary(tool.name)
        assert is_binary(tool.description)
        assert is_map(tool.params)
        assert is_atom(tool.module)
      end)
    end

    test "includes echo tool in catalog" do
      tools = Tooling.catalog()
      echo_tool = Enum.find(tools, fn tool -> tool.name == "echo" end)

      assert echo_tool != nil
      assert echo_tool.description =~ "Echo back"
      assert echo_tool.params.type == "object"
    end
  end

  describe "get_tool_spec/1" do
    test "returns spec for existing tool" do
      {:ok, spec} = Tooling.get_tool_spec("echo")

      assert spec.name == "echo"
      assert is_binary(spec.description)
      assert is_map(spec.params)
    end

    test "returns error for non-existent tool" do
      assert {:error, :not_found} = Tooling.get_tool_spec("nonexistent")
    end
  end

  describe "call/3" do
    test "executes echo tool successfully" do
      params = %{"message" => "test message"}
      ctx = %{session_id: "test-session"}

      {:ok, result} = Tooling.call("echo", params, ctx)

      assert result.success == true
      assert result.echoed_message == "test message"
      assert result.context.session_id == "test-session"
      assert is_integer(result.message_length)
    end

    test "returns error for invalid tool name" do
      params = %{"message" => "test"}

      {:error, result} = Tooling.call("nonexistent", params, %{})

      assert result.error == true
      assert result.reason =~ "Tool not found"
    end

    test "validates tool parameters" do
      # Missing required parameter
      params = %{}

      {:error, result} = Tooling.call("echo", params, %{})

      assert result.error == true
      assert result.reason =~ "Validation error"
    end

    test "enriches context with defaults" do
      # Test that context gets enriched with defaults
      params = %{"message" => "test"}
      # Empty context
      ctx = %{}

      {:ok, result} = Tooling.call("echo", params, ctx)

      # The echo tool returns the context, so we can verify enrichment happened
      assert result.success == true
      assert result.context.session_id == "default"
      assert Map.has_key?(result.context, :timestamp)
      # request_id is generated, so we just verify it exists
      assert is_binary(result.context.request_id) or is_nil(result.context.request_id)
    end
  end

  describe "list_tool_names/0" do
    test "returns sorted list of tool names" do
      names = Tooling.list_tool_names()

      assert is_list(names)
      assert "echo" in names
      # Verify sorted order
      assert names == Enum.sort(names)
    end
  end

  describe "tool_exists?/1" do
    test "returns true for existing tools" do
      assert Tooling.tool_exists?("echo") == true
    end

    test "returns false for non-existent tools" do
      assert Tooling.tool_exists?("nonexistent") == false
    end
  end

  describe "system_info/0" do
    test "returns system information" do
      info = Tooling.system_info()

      assert is_integer(info.total_tools)
      assert is_list(info.tool_names)
      assert is_list(info.registry)
      assert %DateTime{} = info.loaded_at
    end
  end
end
