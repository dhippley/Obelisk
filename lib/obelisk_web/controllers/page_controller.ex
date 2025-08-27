defmodule ObeliskWeb.PageController do
  use ObeliskWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
