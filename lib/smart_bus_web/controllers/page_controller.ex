defmodule SmartBusWeb.PageController do
  import Plug.Conn

  def channel_tester(conn, _params) do
    # Read the static HTML file and send it
    file_path = Path.join([:code.priv_dir(:smart_bus), "static", "channel_tester.html"])
    html_content = File.read!(file_path)

    conn
    |> put_resp_content_type("text/html; charset=utf-8")
    |> send_resp(200, html_content)
  end
end
