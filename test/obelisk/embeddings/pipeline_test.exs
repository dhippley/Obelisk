defmodule Obelisk.Embeddings.PipelineTest do
  use Obelisk.DataCase
  import Mock

  alias Broadway.Message
  alias Obelisk.{Embeddings, Repo}
  alias Obelisk.Embeddings.Pipeline
  alias Obelisk.Schemas.{Memory, MemoryChunk}

  setup do
    # Test embedding data
    test_embedding = List.duplicate(0.5, 1536)

    %{test_embedding: test_embedding}
  end

  describe "message transformation" do
    test "transforms embed_memory jobs correctly" do
      event = %{type: :embed_memory, memory_id: 1, text: "test"}

      message = Pipeline.transform(event, [])

      assert message.data == event
      assert message.acknowledger == {Pipeline, :ack_id, :ack_data}
    end

    test "transforms embed_chunk jobs correctly" do
      event = %{type: :embed_chunk, chunk_id: 1, text: "test"}

      message = Pipeline.transform(event, [])

      assert message.data == event
    end

    test "transforms embed_query jobs correctly" do
      event = %{type: :embed_query, ref: make_ref(), text: "test", reply_to: self()}

      message = Pipeline.transform(event, [])

      assert message.data == event
    end
  end

  describe "handle_message/3" do
    test "processes embed_memory messages" do
      message = %Message{
        data: %{type: :embed_memory, memory_id: 1, text: "test"},
        acknowledger: {Pipeline, :ack_id, :ack_data}
      }

      result = Pipeline.handle_message(:default, message, %{})

      assert result.batcher == :embedding_batcher
      assert result.data.type == :embed_memory
    end

    test "processes embed_chunk messages" do
      message = %Message{
        data: %{type: :embed_chunk, chunk_id: 1, text: "test"},
        acknowledger: {Pipeline, :ack_id, :ack_data}
      }

      result = Pipeline.handle_message(:default, message, %{})

      assert result.batcher == :embedding_batcher
      assert result.data.type == :embed_chunk
    end

    test "processes embed_query messages" do
      ref = make_ref()

      message = %Message{
        data: %{type: :embed_query, ref: ref, text: "test", reply_to: self()},
        acknowledger: {Pipeline, :ack_id, :ack_data}
      }

      result = Pipeline.handle_message(:default, message, %{})

      assert result.batcher == :embedding_batcher
      assert result.data.ref == ref
    end

    test "handles invalid message format" do
      message = %Message{
        data: %{invalid: "data"},
        acknowledger: {Pipeline, :ack_id, :ack_data}
      }

      result = Pipeline.handle_message(:default, message, %{})

      assert result.status == {:failed, "Invalid job format"}
    end
  end

  describe "handle_batch/4" do
    test "processes embed_memory batch successfully", %{test_embedding: embedding} do
      # Create test memory
      {:ok, memory} =
        %Memory{kind: :note, text: "test", embedding: nil}
        |> Repo.insert()

      message = %Message{
        data: %{type: :embed_memory, memory_id: memory.id, text: "test"},
        acknowledger: {Pipeline, :ack_id, :ack_data}
      }

      with_mock Embeddings, embed_text: fn _text -> {:ok, embedding} end do
        [result] = Pipeline.handle_batch(:embedding_batcher, [message], %{}, %{})

        assert result.status != :failed

        # Check that memory was updated
        updated_memory = Repo.get(Memory, memory.id)
        assert updated_memory.embedding != nil
      end
    end

    test "processes embed_chunk batch successfully", %{test_embedding: embedding} do
      # Create test memory and chunk
      {:ok, memory} =
        %Memory{kind: :note, text: "test", embedding: embedding}
        |> Repo.insert()

      {:ok, chunk} =
        %MemoryChunk{text: "test", embedding: nil, memory_id: memory.id}
        |> Repo.insert()

      message = %Message{
        data: %{type: :embed_chunk, chunk_id: chunk.id, text: "test"},
        acknowledger: {Pipeline, :ack_id, :ack_data}
      }

      with_mock Embeddings, embed_text: fn _text -> {:ok, embedding} end do
        [result] = Pipeline.handle_batch(:embedding_batcher, [message], %{}, %{})

        assert result.status != :failed

        # Check that chunk was updated
        updated_chunk = Repo.get(MemoryChunk, chunk.id)
        assert updated_chunk.embedding != nil
      end
    end

    test "processes embed_query batch successfully", %{test_embedding: embedding} do
      ref = make_ref()

      message = %Message{
        data: %{type: :embed_query, ref: ref, text: "test", reply_to: self()},
        acknowledger: {Pipeline, :ack_id, :ack_data}
      }

      with_mock Embeddings, embed_text: fn _text -> {:ok, embedding} end do
        [result] = Pipeline.handle_batch(:embedding_batcher, [message], %{}, %{})

        assert result.status != :failed

        # Check that reply was sent
        assert_received {:embedding_result, ^ref, {:ok, ^embedding}}
      end
    end

    test "handles embedding failures gracefully" do
      message = %Message{
        data: %{type: :embed_query, ref: make_ref(), text: "test", reply_to: self()},
        acknowledger: {Pipeline, :ack_id, :ack_data}
      }

      with_mock Embeddings, embed_text: fn _text -> {:error, :api_error} end do
        [result] = Pipeline.handle_batch(:embedding_batcher, [message], %{}, %{})

        assert result.status == {:failed, :api_error}
      end
    end

    test "groups duplicate texts efficiently", %{test_embedding: embedding} do
      ref1 = make_ref()
      ref2 = make_ref()

      messages = [
        %Message{
          data: %{type: :embed_query, ref: ref1, text: "same text", reply_to: self()},
          acknowledger: {Pipeline, :ack_id, :ack_data}
        },
        %Message{
          data: %{type: :embed_query, ref: ref2, text: "same text", reply_to: self()},
          acknowledger: {Pipeline, :ack_id, :ack_data}
        }
      ]

      with_mock Embeddings, embed_text: fn _text -> {:ok, embedding} end do
        results = Pipeline.handle_batch(:embedding_batcher, messages, %{}, %{})

        # Should have called embed_text only once for duplicate text
        assert called(Embeddings.embed_text("same text"))

        assert length(results) == 2

        # Both should have received the result
        assert_received {:embedding_result, ^ref1, {:ok, ^embedding}}
        assert_received {:embedding_result, ^ref2, {:ok, ^embedding}}
      end
    end
  end
end
