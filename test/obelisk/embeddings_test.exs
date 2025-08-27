defmodule Obelisk.EmbeddingsTest do
  use ExUnit.Case

  alias Obelisk.Embeddings

  describe "embedding_dimensions/1" do
    test "returns correct dimensions for text-embedding-3-small" do
      dimensions = Embeddings.embedding_dimensions(%{model: "text-embedding-3-small"})
      assert dimensions == 1536
    end

    test "returns correct dimensions for text-embedding-3-large" do
      dimensions = Embeddings.embedding_dimensions(%{model: "text-embedding-3-large"})
      assert dimensions == 3072
    end

    test "returns correct dimensions for text-embedding-ada-002" do
      dimensions = Embeddings.embedding_dimensions(%{model: "text-embedding-ada-002"})
      assert dimensions == 1536
    end

    test "returns default dimensions for unknown model" do
      dimensions = Embeddings.embedding_dimensions(%{model: "unknown-model"})
      assert dimensions == 1536
    end

    test "returns default dimensions when no model specified" do
      dimensions = Embeddings.embedding_dimensions()
      assert dimensions == 1536
    end
  end

  describe "embed_text/2" do
    test "returns error for unsupported provider" do
      result = Embeddings.embed_text("test text", %{provider: "unsupported"})
      assert {:error, {:unsupported_provider, "unsupported"}} = result
    end

    test "returns error when OPENAI_API_KEY is not set" do
      # This test will fail if OPENAI_API_KEY is actually set
      # In a real test suite, you'd mock the System.fetch_env! call

      # We test that the function expects the API key to be present
      assert_raise System.EnvError,
                   ~r/could not fetch environment variable "OPENAI_API_KEY"/,
                   fn ->
                     # This will fail if no API key is set
                     Embeddings.embed_text("test")
                   end
    end

    @tag :external_api
    test "validates input types" do
      # Test that non-string inputs are rejected
      assert_raise FunctionClauseError, fn ->
        Embeddings.embed_text(123)
      end

      assert_raise FunctionClauseError, fn ->
        Embeddings.embed_text(nil)
      end
    end
  end

  describe "input validation" do
    test "only accepts string text input" do
      # Test that the function guards work correctly
      assert_raise FunctionClauseError, fn ->
        Embeddings.embed_text(123)
      end
    end
  end
end
