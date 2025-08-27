defmodule Obelisk.Tools.EchoTest do
  use ExUnit.Case, async: true

  alias Obelisk.Tools.Echo

  describe "spec/0" do
    test "returns valid tool specification" do
      spec = Echo.spec()

      assert spec.name == "echo"
      assert is_binary(spec.description)
      assert spec.description =~ "Echo back"

      # Validate parameter schema
      assert spec.params.type == "object"
      assert spec.params.required == ["message"]
      assert Map.has_key?(spec.params.properties, :message)
      assert spec.params.properties.message.type == "string"
    end
  end

  describe "call/2" do
    test "echoes message with metadata" do
      params = %{"message" => "Hello, World!"}

      ctx = %{
        session_id: "test-session",
        timestamp: ~U[2025-01-01 12:00:00Z],
        request_id: "req-123"
      }

      {:ok, result} = Echo.call(params, ctx)

      assert result.echoed_message == "Hello, World!"
      assert result.context.session_id == "test-session"
      assert result.context.timestamp == ~U[2025-01-01 12:00:00Z]
      assert result.context.request_id == "req-123"
      assert result.message_length == 13
      assert result.message_words == 2
    end

    test "counts words correctly" do
      params = %{"message" => "  This   is   a    test  message  "}
      ctx = %{}

      {:ok, result} = Echo.call(params, ctx)

      assert result.message_words == 5
      # Actual length of the string
      assert result.message_length == 34
    end

    test "handles empty message" do
      params = %{"message" => ""}
      ctx = %{}

      {:ok, result} = Echo.call(params, ctx)

      assert result.echoed_message == ""
      assert result.message_length == 0
      assert result.message_words == 0
    end

    test "handles single word" do
      params = %{"message" => "Hello"}
      ctx = %{}

      {:ok, result} = Echo.call(params, ctx)

      assert result.message_words == 1
      assert result.message_length == 5
    end
  end
end
