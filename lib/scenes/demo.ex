defmodule Scenic.Scrollable.Scene.Demo do
  use Scenic.Scene

  alias Scenic.Graph
  alias Scenic.Primitive.Style.Theme
  import Scenic.Scrollable.Components, only: [scrollable: 4]
  import Scenic.Components, only: [button: 3]
  import Scenic.Primitives

  @moduledoc false

  # Scene to demonstrate the scrollable components functionality

  @impl Scenic.Scene
  def init(_, _) do
    Graph.build(font: :roboto, font_size: 24)
    |> scrollable(
      %{frame: {500, 500}, content: %{x: 0, y: 15, width: 1200, height: 2200}},
      fn graph ->
        {:ok, text} = File.read("README.md")

        button(graph, "ok", translate: {25, 10})
        |> text(text, translate: {10, 125})
      end,
      translate: {10, 10},
      scroll_position: {0, 0},
      scroll_hotkeys: %{up: "w", down: "s", left: "d", right: "a"},
      scroll_drag: %{mouse_buttons: [:left]},
      scroll_bar: [scroll_buttons: true, scroll_bar_theme: Theme.preset(:primary)]
    )
    |> push_graph()
    |> ResultEx.return()
  end
end
