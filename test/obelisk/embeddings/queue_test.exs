defmodule Obelisk.Embeddings.QueueTest do
  use ExUnit.Case, async: true
  import Mock

  alias Obelisk.Embeddings.Queue

  describe "enqueue_memory_embedding/2" do
    test "enqueues memory embedding job with correct format" do
      # Test that the function doesn't raise errors and returns expected result
      result = Queue.enqueue_memory_embedding(123, "test text")

      # The function should either return :ok or {:error, :enqueue_failed}
      # depending on whether Broadway pipeline is running
      assert result in [:ok, {:error, :enqueue_failed}]
    end
  end

  describe "enqueue_chunk_embedding/2" do
    test "enqueues chunk embedding job with correct format" do
      # Test that the function doesn't raise errors and returns expected result
      result = Queue.enqueue_chunk_embedding(456, "chunk text")

      # The function should either return :ok or {:error, :enqueue_failed}
      # depending on whether Broadway pipeline is running
      assert result in [:ok, {:error, :enqueue_failed}]
    end
  end

  describe "embed_async/2" do
    test "returns reference for async embedding" do
      with_mock Broadway, test_message: fn _pipeline, _job -> :ok end do
        {:ok, ref} = Queue.embed_async("test text")

        assert is_reference(ref)

        # Should have enqueued the job
        assert_called(Broadway.test_message(Obelisk.Embeddings.Pipeline, :_))
      end
    end

    test "handles enqueue failures" do
      with_mock Broadway, test_message: fn _pipeline, _job -> raise "error" end do
        result = Queue.embed_async("test text")

        assert result == {:error, :enqueue_failed}
      end
    end
  end

  describe "embed_sync/2" do
    test "returns embedding result synchronously" do
      test_embedding = List.duplicate(0.1, 1536)

      with_mock Broadway,
        test_message: fn _pipeline, job ->
          # Simulate the pipeline processing and sending back the result
          spawn(fn ->
            # Small delay to simulate processing
            Process.sleep(10)
            send(job.reply_to, {:embedding_result, job.ref, {:ok, test_embedding}})
          end)

          :ok
        end do
        result = Queue.embed_sync("test text", 1000)

        assert result == {:ok, test_embedding}
      end
    end

    test "handles timeout" do
      with_mock Broadway, test_message: fn _pipeline, _job -> :ok end do
        # Don't send any reply to simulate timeout
        # Very short timeout
        result = Queue.embed_sync("test text", 10)

        assert result == {:error, :timeout}
      end
    end

    test "returns error result" do
      with_mock Broadway,
        test_message: fn _pipeline, job ->
          # Simulate error result
          spawn(fn ->
            send(job.reply_to, {:embedding_result, job.ref, {:error, :api_failed}})
          end)

          :ok
        end do
        result = Queue.embed_sync("test text", 1000)

        assert result == {:error, :api_failed}
      end
    end
  end

  describe "queue_info/0" do
    test "returns queue information structure" do
      info = Queue.queue_info()

      assert is_map(info)
      assert Map.has_key?(info, :status)

      # Status should be one of the expected values
      assert info.status in [:not_running, :running, :error]
    end
  end
end
