defmodule Obelisk.LLM do
  @moduledoc """
  Behaviour for LLM providers.

  Defines the interface that all LLM providers must implement for chat completions
  and streaming responses.
  """

  @doc """
  Send a chat completion request to the LLM provider.

  ## Parameters
  - `messages`: List of message maps with `role` and `content` keys
  - `opts`: Options map that may include `model`, `temperature`, `provider`, etc.

  ## Returns
  - `{:ok, response}` on success where response contains the completion
  - `{:error, reason}` on failure
  """
  @callback chat(messages :: list(), opts :: map()) :: {:ok, map()} | {:error, term()}

  @doc """
  Send a streaming chat completion request to the LLM provider.

  ## Parameters
  - `messages`: List of message maps with `role` and `content` keys  
  - `opts`: Options map that may include `model`, `temperature`, `provider`, etc.
  - `callback`: Function called with each streaming chunk

  ## Returns
  - `:ok` when stream completes successfully
  - `{:error, reason}` on failure
  """
  @callback stream_chat(messages :: list(), opts :: map(), callback :: (map() -> any())) ::
              :ok | {:error, term()}
end
