defmodule Obelisk.Embeddings.Queue do
  @moduledoc """
  Queue interface for embedding jobs.

  Provides both synchronous and asynchronous interfaces for embedding generation.
  Asynchronous jobs are processed through the Broadway pipeline for efficiency.
  """

  alias Obelisk.Embeddings.Pipeline

  require Logger

  @doc """
  Enqueue an embedding job for a memory record.

  This will update the memory record with the generated embedding once processed.
  """
  def enqueue_memory_embedding(memory_id, text) when is_integer(memory_id) and is_binary(text) do
    job = %{
      type: :embed_memory,
      memory_id: memory_id,
      text: text
    }

    send_to_pipeline(job)
  end

  @doc """
  Enqueue an embedding job for a memory chunk.

  This will update the memory chunk record with the generated embedding once processed.
  """
  def enqueue_chunk_embedding(chunk_id, text) when is_integer(chunk_id) and is_binary(text) do
    job = %{
      type: :embed_chunk,
      chunk_id: chunk_id,
      text: text
    }

    send_to_pipeline(job)
  end

  @doc """
  Get embedding for text asynchronously.

  Returns immediately with a reference. The caller will receive a message:
  `{:embedding_result, ref, {:ok, embedding} | {:error, reason}}`

  ## Parameters
  - `text`: Text to embed
  - `timeout`: Optional timeout in milliseconds (default: 30 seconds)

  ## Returns
  - `{:ok, ref}` - Reference for tracking the result
  - `{:error, reason}` - If the job couldn't be enqueued
  """
  def embed_async(text, _timeout \\ 30_000) when is_binary(text) do
    ref = make_ref()

    job = %{
      type: :embed_query,
      ref: ref,
      text: text,
      reply_to: self()
    }

    case send_to_pipeline(job) do
      :ok ->
        {:ok, ref}

      error ->
        error
    end
  end

  @doc """
  Get embedding for text synchronously with async processing.

  This uses the async pipeline but blocks until the result is available.
  More efficient than direct embedding for repeated text as it benefits from batching.

  ## Parameters
  - `text`: Text to embed  
  - `timeout`: Timeout in milliseconds (default: 30 seconds)

  ## Returns
  - `{:ok, embedding}` on success
  - `{:error, reason}` on failure
  """
  def embed_sync(text, timeout \\ 30_000) when is_binary(text) do
    case embed_async(text, timeout) do
      {:ok, ref} ->
        receive do
          {:embedding_result, ^ref, result} -> result
        after
          timeout -> {:error, :timeout}
        end

      error ->
        error
    end
  end

  @doc """
  Get the current queue size and processing stats.

  Useful for monitoring the embedding pipeline health.
  """
  def queue_info do
    case Broadway.producer_names(Pipeline) do
      [] ->
        %{status: :not_running, queue_size: 0}

      producers ->
        # Get info from the first producer
        producer = hd(producers)
        info = GenStage.demand(producer)

        %{
          status: :running,
          queue_size: info[:queue_size] || 0,
          demand: info[:demand] || 0
        }
    end
  rescue
    _ -> %{status: :error, queue_size: :unknown}
  end

  # Private functions

  defp send_to_pipeline(job) do
    # In production, this would send to an actual message queue
    # For now, we'll use the Broadway test utilities to inject messages

    # Send the job to the Broadway pipeline
    # For DummyProducer, we need to use Broadway's test utilities
    Broadway.test_message(Pipeline, job)
    :ok
  rescue
    error ->
      Logger.error("Failed to enqueue embedding job: #{inspect(error)}")
      {:error, :enqueue_failed}
  end
end
