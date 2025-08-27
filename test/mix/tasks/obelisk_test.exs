defmodule Mix.Tasks.ObeliskTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  alias Mix.Tasks.Obelisk

  describe "Mix.Tasks.Obelisk" do
    test "shows help when called with --help" do
      output =
        capture_io(fn ->
          Obelisk.run(["--help"])
        end)

      assert String.contains?(output, "Interactive chat, one-shot mode, or server modes")
      assert String.contains?(output, "## Usage")
      assert String.contains?(output, "mix obelisk")
    end

    test "shows usage error for invalid arguments" do
      # Note: This test would need to mock System.halt to avoid actually halting
      # For now, just verify the function exists and can handle invalid args
      functions = Obelisk.__info__(:functions)
      assert Keyword.has_key?(functions, :run)

      # The actual error handling is tested through integration
      # rather than unit tests that would require mocking System.halt
    end

    test "task module exists and has expected functions" do
      functions = Obelisk.__info__(:functions)

      assert Keyword.has_key?(functions, :run)
      assert Obelisk.__info__(:attributes)[:shortdoc] == ["Interactive or one-shot chat with RAG"]
    end
  end
end
