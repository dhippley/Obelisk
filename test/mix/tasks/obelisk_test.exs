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

      assert String.contains?(output, "Interactive chat or one-shot mode")
      assert String.contains?(output, "## Usage")
      assert String.contains?(output, "mix obelisk")
    end

    test "shows usage error for invalid arguments" do
      output =
        capture_io(:stderr, fn ->
          catch_exit(Obelisk.run(["--invalid", "arg"]))
        end)

      assert String.contains?(output, "Usage: mix obelisk")
    end

    test "task module exists and has expected functions" do
      functions = Obelisk.__info__(:functions)

      assert Keyword.has_key?(functions, :run)
      assert Obelisk.__info__(:attributes)[:shortdoc] == ["Interactive or one-shot chat with RAG"]
    end
  end
end
