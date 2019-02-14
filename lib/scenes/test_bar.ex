defmodule ScenicScrollable.Scene.TestBar do
  use Scenic.Scene

  alias Scenic.Graph

  import Scenic.Primitives
  # import Scenic.Components

  @note """
    This is a very simple starter application.

    If you want a more full-on example, please start from:

    mix scenic.new.example
  """

  # ============================================================================
  # setup

  # --------------------------------------------------------
  def init(_, _) do
    Graph.build(font: :roboto, font_size: 24)
    |> Scenic.Scrollable.ScrollBar.add_to_graph(%{
      width: 10,
      height: 300,
      content_size: 600,
      scroll_position: 100,
      direction: :vertical
    }, translate: {10, 50})
    |> push_graph()
    |> ResultEx.return()
  end
end
