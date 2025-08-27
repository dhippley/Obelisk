defmodule ObeliskWeb.Router do
  use ObeliskWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ObeliskWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ObeliskWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/chat", ChatLive, :index
    live "/memory", MemoryLive, :index
  end

  # API routes
  scope "/api/v1", ObeliskWeb.Api.V1 do
    pipe_through :api

    # Chat endpoints
    post "/chat", ChatController, :create
    get "/chat/:session_id", ChatController, :show

    # Memory endpoints
    post "/memory/search", MemoryController, :search
    post "/memory", MemoryController, :create
    get "/memory", MemoryController, :index

    # Session endpoints
    get "/sessions", SessionController, :index
    post "/sessions", SessionController, :create
    get "/sessions/:id", SessionController, :show
    delete "/sessions/:id", SessionController, :delete
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:obelisk, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ObeliskWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
