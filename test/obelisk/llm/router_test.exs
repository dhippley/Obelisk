defmodule Obelisk.LLM.RouterTest do
  use ExUnit.Case, async: true
  import Mock

  alias Obelisk.LLM.{Router, OpenAI}

  describe "available_providers/0" do
    test "returns list of available providers" do
      providers = Router.available_providers()

      assert is_list(providers)
      assert "openai" in providers
      assert "anthropic" in providers
      assert "ollama" in providers
    end
  end

  describe "provider selection" do
    test "selects provider from options" do
      # Mock the provider modules to avoid actual API calls
      assert_raise ArgumentError, fn ->
        Router.chat([%{role: "user", content: "test"}], %{provider: "nonexistent"})
      end
    end

    test "defaults to openai when no provider specified" do
      with_mock OpenAI, chat: fn _messages, _opts -> {:ok, "OpenAI response"} end do
        result = Router.chat([%{role: "user", content: "test"}], %{})

        assert {:ok, "OpenAI response"} = result
        assert called(OpenAI.chat([%{role: "user", content: "test"}], %{}))
      end
    end
  end

  describe "error handling" do
    test "raises error for unknown provider" do
      assert_raise ArgumentError, ~r/Unknown LLM provider: unknown_provider/, fn ->
        Router.chat([%{role: "user", content: "test"}], %{provider: "unknown_provider"})
      end
    end
  end
end
