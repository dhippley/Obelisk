defmodule ObeliskWeb.ChatLiveTest do
  use ObeliskWeb.ConnCase
  import Phoenix.LiveViewTest
  import Mock

  alias Obelisk.{Chat, Memory}

  describe "ChatLive" do
    test "mounts successfully and displays welcome message", %{conn: conn} do
      with_mocks([
        {Memory, [],
         [get_or_create_session: fn _name -> {:ok, %{id: 1, name: "test-session"}} end]},
        {Chat, [], [get_conversation_history: fn _id, _opts -> {:ok, []} end]}
      ]) do
        {:ok, _view, html} = live(conn, "/chat")

        assert html =~ "Start a conversation"
        assert html =~ "Obelisk Chat"
        assert html =~ "New Session"
      end
    end

    test "sends messages and shows form interaction", %{conn: conn} do
      with_mocks([
        {Memory, [],
         [get_or_create_session: fn _name -> {:ok, %{id: 1, name: "test-session"}} end]},
        {Chat, [], [get_conversation_history: fn _id, _opts -> {:ok, []} end]}
      ]) do
        {:ok, view, _html} = live(conn, "/chat")

        # Update the message input
        view |> element("input[name=message]") |> render_change(%{"message" => "Hello!"})

        # Should update the current_message assign
        html = render(view)
        assert html =~ "value=\"Hello!\""

        # Should have form elements present
        assert has_element?(view, "form input[name=message]")
        assert has_element?(view, "button[type=submit]")
      end
    end

    test "clears chat history", %{conn: conn} do
      with_mocks([
        {Memory, [],
         [get_or_create_session: fn _name -> {:ok, %{id: 1, name: "test-session"}} end]},
        {Chat, [],
         [
           get_conversation_history: fn _id, _opts -> {:ok, []} end,
           clear_history: fn _session -> {:ok, :cleared} end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/chat")

        # Click clear history
        view |> element("button", "Clear History") |> render_click()

        # Should show success message
        assert render(view) =~ "Chat history cleared"
      end
    end

    test "creates new session", %{conn: conn} do
      with_mocks([
        {Memory, [],
         [get_or_create_session: fn _name -> {:ok, %{id: 1, name: "test-session"}} end]},
        {Chat, [], [get_conversation_history: fn _id, _opts -> {:ok, []} end]}
      ]) do
        {:ok, view, _html} = live(conn, "/chat")

        # Click new session
        view |> element("button", "New Session") |> render_click()

        # Should show success message
        assert render(view) =~ "Started new chat session"
      end
    end

    test "toggles sidebar", %{conn: conn} do
      with_mocks([
        {Memory, [],
         [get_or_create_session: fn _name -> {:ok, %{id: 1, name: "test-session"}} end]},
        {Chat, [], [get_conversation_history: fn _id, _opts -> {:ok, []} end]}
      ]) do
        {:ok, view, html} = live(conn, "/chat")

        # Initially sidebar should be open (width 80)
        assert html =~ "w-80"

        # Click toggle
        view |> element("button[phx-click=toggle_sidebar]") |> render_click()

        # Should be collapsed (width 16)
        html = render(view)
        assert html =~ "w-16"
      end
    end

    test "switches provider", %{conn: conn} do
      with_mocks([
        {Memory, [],
         [get_or_create_session: fn _name -> {:ok, %{id: 1, name: "test-session"}} end]},
        {Chat, [], [get_conversation_history: fn _id, _opts -> {:ok, []} end]}
      ]) do
        {:ok, view, _html} = live(conn, "/chat")

        # Switch provider
        view
        |> element("select[name=provider]")
        |> render_change(%{"provider" => "anthropic"})

        # Should show message about provider switch
        assert render(view) =~ "Switched to Anthropic"
      end
    end
  end
end
