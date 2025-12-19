defmodule SmartBusWeb.ErrorJSON do
  @doc """
  Renders an error JSON response.
  """
  def render("404.json", _assigns) do
    %{errors: %{detail: "Not Found"}}
  end

  def render("500.json", _assigns) do
    %{errors: %{detail: "Internal Server Error"}}
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
