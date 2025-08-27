defmodule Obelisk.CLITest do
  use ExUnit.Case, async: true

  alias Obelisk.CLI

  describe "CLI module" do
    test "CLI module has expected functions" do
      functions = CLI.__info__(:functions)

      assert Keyword.has_key?(functions, :repl)
    end

    test "module loads correctly and has expected structure" do
      assert CLI.__info__(:module) == Obelisk.CLI
      assert is_list(CLI.__info__(:functions))
    end
  end
end
