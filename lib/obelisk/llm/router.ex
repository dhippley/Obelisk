defmodule Obelisk.LLM.Router do
  @moduledoc """
  Router for dispatching LLM requests to different providers.

  Automatically selects the provider based on configuration or request options.
  """

  @providers %{
    "openai" => Obelisk.LLM.OpenAI
    # Future providers:
    # "anthropic" => Obelisk.LLM.Anthropic,
    # "ollama" => Obelisk.LLM.Ollama,
    # "gemini" => Obelisk.LLM.Gemini
  }

  @default_provider "openai"

  @doc """
  Send a chat completion request using the configured provider.

  ## Parameters
  - `messages`: List of message maps with `role` and `content` keys
  - `opts`: Options map that may include `provider`, `model`, `temperature`, etc.

  The provider can be specified in opts[:provider] or via LLM_PROVIDER env var.
  """
  def chat(messages, opts \\ %{}) do
    provider_name = get_provider_name(opts)
    provider_module = get_provider_module(provider_name)

    provider_module.chat(messages, opts)
  end

  @doc """
  Send a streaming chat completion request using the configured provider.
  """
  def stream_chat(messages, opts \\ %{}, callback) do
    provider_name = get_provider_name(opts)
    provider_module = get_provider_module(provider_name)

    provider_module.stream_chat(messages, opts, callback)
  end

  @doc """
  Get the list of available providers.
  """
  def available_providers do
    Map.keys(@providers)
  end

  # Private functions

  defp get_provider_name(opts) do
    Map.get(opts, :provider) || System.get_env("LLM_PROVIDER", @default_provider)
  end

  defp get_provider_module(provider_name) when is_binary(provider_name) do
    case Map.fetch(@providers, provider_name) do
      {:ok, module} ->
        module

      :error ->
        available = Enum.join(Map.keys(@providers), ", ")

        raise ArgumentError, """
        Unknown LLM provider: #{provider_name}

        Available providers: #{available}

        Set LLM_PROVIDER environment variable or pass provider in options.
        """
    end
  end
end
