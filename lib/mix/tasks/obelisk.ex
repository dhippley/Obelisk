defmodule Mix.Tasks.Obelisk do
  @moduledoc """
  Interactive chat or one-shot mode for Obelisk.

  ## Usage

      mix obelisk                    # Interactive REPL (default session)
      mix obelisk "What is Elixir?"  # One-shot mode
      mix obelisk --help             # Show help

  ## Examples

      # Start interactive chat
      mix obelisk

      # Ask a single question
      mix obelisk "Explain functional programming"

      # Get help
      mix obelisk --help
  """

  use Mix.Task

  @shortdoc "Interactive or one-shot chat with RAG"

  def run([]) do
    Application.ensure_all_started(:obelisk)
    Obelisk.CLI.repl()
  end

  def run(["--help"]) do
    IO.puts(@moduledoc)
  end

  def run([text]) when is_binary(text) do
    Application.ensure_all_started(:obelisk)

    case Obelisk.Chat.send_message(text, "default") do
      {:ok, result} ->
        IO.puts(result.response)

      {:error, reason} ->
        Mix.shell().error("Error: #{inspect(reason)}")
        System.halt(1)
    end
  end

  def run(_args) do
    Mix.shell().error("""
    Usage: mix obelisk [TEXT]

    Arguments:
      TEXT     Single message for one-shot mode
      --help   Show this help

    Examples:
      mix obelisk                    # Interactive REPL
      mix obelisk "What is Elixir?"  # One-shot mode
    """)

    System.halt(1)
  end
end
