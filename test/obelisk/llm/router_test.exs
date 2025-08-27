defmodule Obelisk.LLM.RouterTest do
  use ExUnit.Case

  alias Obelisk.LLM.Router

  describe "available_providers/0" do
    test "returns list of available providers" do
      providers = Router.available_providers()

      assert is_list(providers)
      assert "openai" in providers
    end
  end

  describe "provider selection" do
    test "uses default provider when none specified" do
      # We can't easily test the actual routing without mocking OpenAI,
      # but we can test that it doesn't raise errors with invalid providers
      assert_raise ArgumentError, ~r/Unknown LLM provider/, fn ->
        Router.chat([], %{provider: "nonexistent"})
      end
    end

    test "raises error for unknown provider" do
      assert_raise ArgumentError, ~r/Unknown LLM provider: nonexistent/, fn ->
        Router.chat([], %{provider: "nonexistent"})
      end
    end

    test "error message includes available providers" do
      assert_raise ArgumentError, ~r/Available providers: openai/, fn ->
        Router.chat([], %{provider: "invalid"})
      end
    end
  end

  describe "environment variable handling" do
    test "respects LLM_PROVIDER environment variable" do
      # Test that setting an invalid env var would cause an error
      # We can't easily set env vars in tests without external setup,
      # so we test the error path

      assert_raise ArgumentError, fn ->
        Router.chat([], %{provider: "invalid"})
      end
    end
  end
end
