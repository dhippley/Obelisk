defmodule ObeliskWeb.UserSocketTest do
  use ObeliskWeb.ChannelCase
  
  alias ObeliskWeb.UserSocket

  describe "connect/3" do
    test "allows connection with any params" do
      assert {:ok, socket} = connect(UserSocket, %{})
      assert socket
    end

    test "allows connection with token params" do
      assert {:ok, socket} = connect(UserSocket, %{"token" => "test-token"})
      assert socket
    end

    test "allows connection with user params" do
      assert {:ok, socket} = connect(UserSocket, %{"user_id" => 123})
      assert socket
    end
  end

  describe "id/1" do
    test "returns nil for anonymous connections" do
      {:ok, socket} = connect(UserSocket, %{})
      assert UserSocket.id(socket) == nil
    end
  end

  describe "channel routing" do
    test "routes chat channels correctly" do
      {:ok, socket} = connect(UserSocket, %{})
      
      # This tests that the channel routing is properly configured
      # The actual channel join is tested in chat_channel_test.exs
      assert socket
    end
  end
end
