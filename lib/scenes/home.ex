defmodule ScenicScrollable.Scene.Home do
  use Scenic.Scene

  alias Scenic.Graph
  import Scenic.Scrollable.Components, only: [scrollable: 4]

  import Scenic.Primitives
  # import Scenic.Components

  @note """
    This is a very simple starter application.

    If you want a more full-on example, please start from:

    mix scenic.new.example
  """

  @graph Graph.build(font: :roboto, font_size: 24)
         |> text(@note, translate: {20, 60})

  # ============================================================================
  # setup

  # --------------------------------------------------------
  def init(_, _) do
    Graph.build(font: :roboto, font_size: 24)
    |> scrollable(
      %{frame: {200, 200}, content: %{x: 0, y: 15, width: 600, height: 300}},
      fn graph ->
        text(graph, @note)
      end,
      translate: {100, 100},
      scroll_position: {0, 0}
    )
    #    |> group(fn graph ->
    #      graph
    #      |> text(@note, translate: {0, 15})
    #    end, scissor: {200, 200}, translate: {100, 100})
    |> push_graph()
    |> ResultEx.return()
  end
end
