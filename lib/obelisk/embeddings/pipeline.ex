defmodule Obelisk.Embeddings.Pipeline do
  @moduledoc """
  Broadway pipeline for processing embedding jobs asynchronously.

  This pipeline batches embedding requests to improve efficiency and handle
  rate limits from embedding providers like OpenAI.
  """

  use Broadway

  alias Broadway.Message
  alias Obelisk.{Embeddings, Repo}
  alias Obelisk.Schemas.{Memory, MemoryChunk}

  require Logger

  # @producer_module BroadwayRabbitMQ.Producer  # Unused for now
  @batch_size 10
  # 2 seconds
  @batch_timeout 2000

  def start_link(_opts \\ []) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {Broadway.DummyProducer, []},
        transformer: {__MODULE__, :transform, []}
      ],
      processors: [
        default: [
          concurrency: 5
        ]
      ],
      batchers: [
        embedding_batcher: [
          batch_size: @batch_size,
          batch_timeout: @batch_timeout,
          concurrency: 2
        ]
      ],
      context: %{
        embedding_provider: "openai"
      }
    )
  end

  @doc """
  Transform incoming messages into Broadway messages.
  """
  def transform(event, _opts) do
    %Message{
      data: event,
      acknowledger: {__MODULE__, :ack_id, :ack_data}
    }
  end

  @impl Broadway
  def handle_message(_processor, message, _context) do
    case message.data do
      %{type: :embed_memory, memory_id: memory_id, text: text} ->
        Logger.debug("Processing embed_memory job for memory_id: #{memory_id}")

        message
        |> Message.put_data(%{
          type: :embed_memory,
          memory_id: memory_id,
          text: text
        })
        |> Message.put_batcher(:embedding_batcher)

      %{type: :embed_chunk, chunk_id: chunk_id, text: text} ->
        Logger.debug("Processing embed_chunk job for chunk_id: #{chunk_id}")

        message
        |> Message.put_data(%{
          type: :embed_chunk,
          chunk_id: chunk_id,
          text: text
        })
        |> Message.put_batcher(:embedding_batcher)

      %{type: :embed_query, ref: ref, text: text, reply_to: reply_to} ->
        Logger.debug("Processing embed_query job for ref: #{ref}")

        message
        |> Message.put_data(%{
          type: :embed_query,
          ref: ref,
          text: text,
          reply_to: reply_to
        })
        |> Message.put_batcher(:embedding_batcher)

      invalid ->
        Logger.warning("Invalid embedding job format: #{inspect(invalid)}")
        Message.failed(message, "Invalid job format")
    end
  end

  @impl Broadway
  def handle_batch(:embedding_batcher, messages, _batch_info, _context) do
    Logger.debug("Processing batch of #{length(messages)} embedding jobs")

    # Group messages by text to avoid duplicate embeddings for same text
    text_to_jobs =
      messages
      |> Enum.group_by(fn msg -> msg.data.text end)

    # Process embeddings in batch
    results =
      text_to_jobs
      |> Map.keys()
      |> process_embeddings_batch()

    # Update database and send replies
    messages
    |> Enum.map(fn message ->
      text = message.data.text

      case Map.get(results, text) do
        {:ok, embedding} ->
          handle_successful_embedding(message, embedding)
          message

        {:error, reason} ->
          Logger.error("Embedding failed for text: #{inspect(reason)}")
          Message.failed(message, reason)
      end
    end)
  end

  # Private functions

  defp process_embeddings_batch(texts) do
    texts
    |> Enum.map(fn text ->
      case Embeddings.embed_text(text) do
        {:ok, embedding} -> {text, {:ok, embedding}}
        {:error, reason} -> {text, {:error, reason}}
      end
    end)
    |> Map.new()
  end

  defp handle_successful_embedding(message, embedding) do
    case message.data do
      %{type: :embed_memory, memory_id: memory_id} ->
        update_memory_embedding(memory_id, embedding)

      %{type: :embed_chunk, chunk_id: chunk_id} ->
        update_chunk_embedding(chunk_id, embedding)

      %{type: :embed_query, ref: ref, reply_to: reply_to} ->
        send(reply_to, {:embedding_result, ref, {:ok, embedding}})
    end
  end

  defp update_memory_embedding(memory_id, embedding) do
    case Repo.get(Memory, memory_id) do
      nil ->
        Logger.warning("Memory not found for embedding update: #{memory_id}")

      memory ->
        Memory.changeset(memory, %{embedding: embedding})
        |> Repo.update()
        |> case do
          {:ok, _} ->
            Logger.debug("Updated embedding for memory: #{memory_id}")

          {:error, reason} ->
            Logger.error("Failed to update memory embedding: #{inspect(reason)}")
        end
    end
  end

  defp update_chunk_embedding(chunk_id, embedding) do
    case Repo.get(MemoryChunk, chunk_id) do
      nil ->
        Logger.warning("MemoryChunk not found for embedding update: #{chunk_id}")

      chunk ->
        MemoryChunk.changeset(chunk, %{embedding: embedding})
        |> Repo.update()
        |> case do
          {:ok, _} ->
            Logger.debug("Updated embedding for chunk: #{chunk_id}")

          {:error, reason} ->
            Logger.error("Failed to update chunk embedding: #{inspect(reason)}")
        end
    end
  end

  # Required for Broadway.DummyProducer
  def ack(_ack_ref, successful, _failed) do
    Logger.debug("Acknowledged #{length(successful)} successful embedding jobs")
    :ok
  end
end
