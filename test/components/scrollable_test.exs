defmodule Scenic.ScrollableTest do
  use ExUnit.Case, async: false
  doctest Scenic.Scrollable
  alias Scenic.Scrollable
  alias Scenic.Scrollable.Hotkeys
  alias Scenic.Scrollable.Drag
  alias Scenic.Scrollable.ScrollBars
  alias Scenic.Scrollable.Acceleration
  alias Scenic.Scrollable.PositionCap
  alias Scenic.Scrollable.Components
  alias Scenic.Scrollable.TestParentScene
  alias Scenic.Primitive.Style.Theme
  alias Scenic.Graph

  setup_all context do
    graph = Graph.build()

    settings = %{
      case_1: %{
        frame: {100, 200},
        content: {400, 600}
      },
      case_2: %{
        frame: {50.123, 60.321},
        content: %{x: 12.34, y: 45.67, width: 123.45, height: 678.9}
      }
    }

    builders = %{
      case_1: fn graph ->
        Scenic.Primitives.text(graph, "testing case 1")
      end,
      case_2: fn graph ->
        Scenic.Primitives.text(graph, "testing case 2")
      end
    }

    styles = %{
      case_1: [
        id: :scrollable_test_case_1
      ],
      case_2: [
        scroll_position: {1, 2},
        scroll_acceleration: %{
          acceleration: 12,
          mass: 1.1,
          counter_pressure: 0.2,
        },
        scroll_hotkeys: %{
          up: "w",
          down: "s",
          left: "a",
          right: "d"
        },
        scroll_fps: 60,
        scroll_drag: %{
          mouse_buttons: [:left, :middle, :right]
        },
        scroll_bar: [scroll_buttons: true, scroll_bar_theme: Theme.preset(:light)],
        translate: {100, 50},
        id: :scrollable_test_case_2
      ]
    }

    start = fn case_number ->
      {:ok, {parent_pid, _}} = TestParentScene.inspect()

      graph = Components.scrollable(graph, settings[case_number], builders[case_number], styles[case_number])
      TestParentScene.set_graph(parent_pid, graph)
      Scrollable.inspect_until_found()
    end

    stop = fn pid ->
      {:ok, {parent_pid, _}} = TestParentScene.inspect()

      TestParentScene.set_graph(parent_pid, graph)
      TestParentScene.clear_event_history(parent_pid)
      Scrollable.wait_until_destroyed(pid)
    end

    Map.put(context, :start, start)
    |> Map.put(:stop, stop)
  end

  test "verify" do
    assert Scrollable.verify(nil) == :invalid_input
    assert Scrollable.verify(%{}) == :invalid_input
    assert Scrollable.verify(%{content: %{}}) == :invalid_input
    assert Scrollable.verify(%{content: {1, 2}}) == :invalid_input
    assert Scrollable.verify(%{content: {1, 2}, frame: {3, 4}}) == :invalid_input
    assert Scrollable.verify(%{content: %{x: 1, y: 2, width: 3, height: 4}, frame: {3, 4}}) == :invalid_input

    settings = %{content: {1, 2}, frame: {3, 4}, builder: fn -> :ok end}
    assert Scrollable.verify(settings) == {:ok, settings}

    settings = %{content: %{x: 1, y: 2, width: 3, height: 4}, frame: {3, 4}, builder: fn -> :ok end}
    assert Scrollable.verify(settings) == {:ok, settings}
  end

  test "init case 1", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_1)

    assert %Scrollable{} = state
    assert %Graph{} = state.graph
    assert %{x: 0, y: 0, width: 100, height: 200} == state.frame
    assert %{x: 0, y: 0, width: 400, height: 600} == state.content
    assert {0, 0} == state.scroll_position
    assert 30 == state.fps
    assert %Acceleration{
      acceleration: 20,
      mass: 1,
      counter_pressure: 0.1,
      force: {0, 0},
      speed: {0, 0}
    } == state.acceleration
    assert %Hotkeys{
      key_map: %{
        up: :none,
        down: :none,
        left: :none,
        right: :none
      },
      key_pressed_states: %{
        up: :released,
        down: :released,
        left: :released,
        right: :released
      }
    } == state.hotkeys
    assert %Drag{
      enabled_buttons: [],
      drag_state: :idle,
      drag_start_content_position: :none,
      drag_start: :none,
      current: :none
    } == state.drag_state
    assert %PositionCap{
      min: {:some, {-300, -400}},
      max: {:some, {0, 0}}
    } == state.position_caps
    assert not state.focused
    assert not state.animating
    assert :none == state.scroll_bars

    stop.(pid)
  end

end
