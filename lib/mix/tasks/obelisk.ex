defmodule Mix.Tasks.Obelisk do
  @moduledoc """
  Interactive chat, one-shot mode, or server modes for Obelisk.

  ## Usage

      mix obelisk                    # Interactive REPL (default session)
      mix obelisk "What is Elixir?"  # One-shot mode
      mix obelisk --mode mcp         # Start MCP server (JSON-RPC over stdio)
      mix obelisk --help             # Show help

  ## Examples

      # Start interactive chat
      mix obelisk

      # Ask a single question
      mix obelisk "Explain functional programming"

      # Start MCP server for Cursor/Claude integration
      mix obelisk --mode mcp

      # Get help
      mix obelisk --help
  """

  use Mix.Task

  alias Obelisk.MCP.Server

  @shortdoc "Interactive or one-shot chat with RAG"

  def run([]) do
    Application.ensure_all_started(:obelisk)
    Obelisk.CLI.repl()
  end

  def run(["--help"]) do
    IO.puts(@moduledoc)
  end

  def run(["--mode", "mcp"]) do
    Application.ensure_all_started(:obelisk)
    Server.start_stdio()
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
    Usage: mix obelisk [TEXT] | [OPTIONS]

    Arguments:
      TEXT           Single message for one-shot mode
      --help         Show this help
      --mode mcp     Start MCP server (JSON-RPC over stdio)

    Examples:
      mix obelisk                    # Interactive REPL
      mix obelisk "What is Elixir?"  # One-shot mode
      mix obelisk --mode mcp         # Start MCP server
    """)

    System.halt(1)
  end
end
