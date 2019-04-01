defmodule Scenic.Scrollable.ComponentsTest do
  use ExUnit.Case
  doctest Scenic.Scrollable.Components
  alias Scenic.Scrollable.Components
  alias Scenic.Primitive.Style.Theme
  alias Scenic.Graph

  setup_all context do
    graph = Graph.build()

    settings = %{
      scrollable: %{
        case_1: %{
          frame: {500, 400},
          content: {1000, 1000}
        },
        case_2: %{
          frame: {100, 200},
          content: %{x: 10, y: 50, width: 300, height: 500}
        }
      },
      scroll_bars: %{
        case_1: %{
          width: 200,
          height: 200,
          content_size: {1000, 1000},
          scroll_position: {0, 0}
        },
        case_2: %{
          width: 300,
          height: 100,
          content_size: {500, 400},
          scroll_position: {50, 25}
        }
      },
      scroll_bar: %{
        case_1: %{
          width: 200,
          height: 10,
          content_size: 1000,
          scroll_position: 0,
          direction: :horizontal
        },
        case_2: %{
          width: 5.45,
          height: 1234.12,
          content_size: 2234.75,
          scroll_position: 1.436,
          direction: :vertical
        }
      }
    }

    styles = %{
      scrollable: %{
        case_1: [id: :test_scrollable_case_1],
        case_2: [
          scroll_position: {10, 20},
          scroll_acceleration: %{
            acceleration: 25,
            mass: 1.5,
            counter_pressure: 0.2
          },
          scroll_hotkeys: %{
            up: "up",
            down: "down",
            left: "left",
            right: "right"
          },
          scroll_fps: 60,
          scroll_drag: %{
            mouse_buttons: [:left, :right, :middle]
          },
          scroll_bar: [
            scroll_buttons: true,
            scroll_bar_theme: Theme.preset(:light),
            scroll_bar_radius: 2,
            scroll_bar_border: 2,
            scroll_drag: %{
              mouse_buttons: [:left, :right, :middle]
            }
          ],
          translate: {50, 100},
          id: :test_scrollable_case_2
        ]
      },
      scroll_bars: %{
        case_1: [id: :test_scroll_bars_case_1],
        case_2: [
          scroll_bar: [
            scroll_buttons: true,
            scroll_bar_theme: Theme.preset(:light),
            scroll_bar_radius: 2,
            scroll_bar_border: 2,
            scroll_drag: %{
              mouse_buttons: [:left, :right, :middle]
            }
          ],
          scroll_drag: %{
            mouse_buttons: [:left, :right, :middle]
          },
          id: :test_scroll_bars_case_2
        ]
      },
      scroll_bar: %{
        case_1: [id: :test_scroll_bar_case_1],
        case_2: [
          scroll_buttons: true,
          scroll_bar_theme: Theme.preset(:dark),
          scroll_bar_radius: 4,
          scroll_bar_border: 1,
          scroll_drag: %{
            mouse_buttons: [:left, :right]
          },
          id: :test_scroll_bar_case_2
        ]
      }
    }

    builder = fn graph ->
      Scenic.Components.text(graph, "1234")
    end

    context
    |> Map.put(:graph, graph)
    |> Map.put(:settings, settings)
    |> Map.put(:styles, styles)
    |> Map.put(:builder, builder)
  end

  test "scrollable add case 1", %{
    graph: graph,
    settings: %{scrollable: settings},
    styles: %{scrollable: styles},
    builder: builder
  } do
    primitive =
      Components.scrollable(graph, settings.case_1, builder, styles.case_1)
      |> Graph.get!(:test_scrollable_case_1)

    assert primitive.module == Scenic.Primitive.SceneRef
    assert primitive.data == {Scenic.Scrollable, Map.put(settings.case_1, :builder, builder)}
    assert primitive.id == :test_scrollable_case_1
  end

  test "scrollable add case 2", %{
    graph: graph,
    settings: %{scrollable: settings},
    styles: %{scrollable: styles},
    builder: builder
  } do
    primitive =
      Components.scrollable(graph, settings.case_2, builder, styles.case_2)
      |> Graph.get!(:test_scrollable_case_2)

    assert primitive.module == Scenic.Primitive.SceneRef
    assert primitive.data == {Scenic.Scrollable, Map.put(settings.case_2, :builder, builder)}
    assert primitive.id == :test_scrollable_case_2
  end

  test "scrollable modify", %{
    graph: graph,
    settings: %{scrollable: settings},
    styles: %{scrollable: styles},
    builder: builder
  } do
    primitive =
      Components.scrollable(graph, settings.case_1, builder, styles.case_1)
      |> Graph.get!(:test_scrollable_case_1)
      |> Components.scrollable(settings.case_2, builder, id: :modified_scrollable)

    assert primitive.module == Scenic.Primitive.SceneRef
    assert primitive.data == {Scenic.Scrollable, Map.put(settings.case_2, :builder, builder)}
    assert primitive.id == :modified_scrollable
  end

  test "scroll_bars add case 1", %{
    graph: graph,
    settings: %{scroll_bars: settings},
    styles: %{scroll_bars: styles}
  } do
    primitive =
      Components.scroll_bars(graph, settings.case_1, styles.case_1)
      |> Graph.get!(:test_scroll_bars_case_1)

    assert primitive.module == Scenic.Primitive.SceneRef
    assert primitive.data == {Scenic.Scrollable.ScrollBars, settings.case_1}
    assert primitive.id == :test_scroll_bars_case_1
  end

  test "scroll_bars add case 2", %{
    graph: graph,
    settings: %{scroll_bars: settings},
    styles: %{scroll_bars: styles}
  } do
    primitive =
      Components.scroll_bars(graph, settings.case_2, styles.case_2)
      |> Graph.get!(:test_scroll_bars_case_2)

    assert primitive.module == Scenic.Primitive.SceneRef
    assert primitive.data == {Scenic.Scrollable.ScrollBars, settings.case_2}
    assert primitive.id == :test_scroll_bars_case_2
  end

  test "scroll_bars modify", %{
    graph: graph,
    settings: %{scroll_bars: settings},
    styles: %{scroll_bars: styles}
  } do
    primitive =
      Components.scroll_bars(graph, settings.case_1, styles.case_1)
      |> Graph.get!(:test_scroll_bars_case_1)
      |> Components.scroll_bars(settings.case_2, id: :modified_scroll_bars)

    assert primitive.module == Scenic.Primitive.SceneRef
    assert primitive.data == {Scenic.Scrollable.ScrollBars, settings.case_2}
    assert primitive.id == :modified_scroll_bars
  end

  test "scroll_bar add case 1", %{
    graph: graph,
    settings: %{scroll_bar: settings},
    styles: %{scroll_bar: styles}
  } do
    primitive =
      Components.scroll_bar(graph, settings.case_1, styles.case_1)
      |> Graph.get!(:test_scroll_bar_case_1)

    assert primitive.module == Scenic.Primitive.SceneRef
    assert primitive.data == {Scenic.Scrollable.ScrollBar, settings.case_1}
    assert primitive.id == :test_scroll_bar_case_1
  end

  test "scroll_bar add case 2", %{
    graph: graph,
    settings: %{scroll_bar: settings},
    styles: %{scroll_bar: styles}
  } do
    primitive =
      Components.scroll_bar(graph, settings.case_2, styles.case_2)
      |> Graph.get!(:test_scroll_bar_case_2)

    assert primitive.module == Scenic.Primitive.SceneRef
    assert primitive.data == {Scenic.Scrollable.ScrollBar, settings.case_2}
    assert primitive.id == :test_scroll_bar_case_2
  end

  test "scroll_bar modify", %{
    graph: graph,
    settings: %{scroll_bar: settings},
    styles: %{scroll_bar: styles}
  } do
    primitive =
      Components.scroll_bar(graph, settings.case_1, styles.case_1)
      |> Graph.get!(:test_scroll_bar_case_1)
      |> Components.scroll_bar(settings.case_2, id: :modified_scroll_bar)

    assert primitive.module == Scenic.Primitive.SceneRef
    assert primitive.data == {Scenic.Scrollable.ScrollBar, settings.case_2}
    assert primitive.id == :modified_scroll_bar
  end
end
