defmodule Scenic.Scrollable.ScrollBarTest do
  use ExUnit.Case, async: false
  doctest Scenic.Scrollable.ScrollBar
  alias Scenic.Scrollable.ScrollBar
  alias Scenic.Scrollable.Components
  alias Scenic.Primitive.Style.Theme
  alias Scenic.Graph
  alias Scenic.Scrollable.TestParentScene

  setup_all context do
    graph = Graph.build()

    settings = %{
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
      },
      case_3: %{
        width: 200,
        height: 10,
        content_size: 1000,
        scroll_position: 0,
        direction: :horizontal
      },
    }

    styles = %{
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
      ],
      case_3: [
        scroll_buttons: true,
        scroll_bar_theme: Theme.preset(:light),
        scroll_bar_radius: 2,
        scroll_bar_border: 2,
        scroll_drag: %{
          mouse_buttons: [:left, :right]
        },
        id: :test_scroll_bar_case_3
      ]

    }

    start = fn case_number ->
      {:ok, {parent_pid, _}} = TestParentScene.inspect()

      graph = Components.scroll_bar(graph, settings[case_number], styles[case_number])
      TestParentScene.set_graph(parent_pid, graph)
      ScrollBar.inspect_until_found()
    end

    stop = fn pid ->
      {:ok, {parent_pid, _}} = TestParentScene.inspect()

      TestParentScene.set_graph(parent_pid, Graph.build())
      TestParentScene.clear_event_history(parent_pid)
      ScrollBar.wait_until_destroyed(pid)
    end

    Map.put(context, :settings, settings)
    |> Map.put(:styles, styles)
    |> Map.put(:start, start)
    |> Map.put(:stop, stop)
    |> Map.put(:graph, graph)
  end

  test "init case 1", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_1)

    assert %ScrollBar{} = state
    assert %Graph{} = state.graph
    assert :test_scroll_bar_case_1 == state.id
    assert is_pid(state.pid)
    assert {:horizontal, 200} == state.width
    assert {:vertical, 10} == state.height
    assert {:horizontal, 200} == state.frame_size
    assert {:horizontal, 1000} == state.content_size
    assert {:horizontal, 0} == state.scroll_position
    assert {:horizontal, 0} == state.last_scroll_position
    assert :horizontal == state.direction
    assert %Scenic.Scrollable.Drag{
      enabled_buttons: [],
      drag_state: :idle,
      drag_start_content_position: :none,
      drag_start: :none,
      current: :none
    } == state.drag_state
    assert %Scenic.Scrollable.PositionCap{
      max: {:some, {160.0, 0}},
      min: {:some, {0, 0}}
    } == state.position_cap
    assert :none == state.scroll_buttons
    assert :released == state.scroll_bar_slider_background
    assert :idle == state.scroll_state
    assert [font: :roboto, font_size: 24] == state.styles

    assert TestParentScene.has_event_fired?(:scroll_bar_initialized)

    stop.(pid)
  end

  test "init case 2", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_2)

    assert %ScrollBar{} = state
    assert %Graph{} = state.graph
    assert :test_scroll_bar_case_2 == state.id
    assert is_pid(state.pid)
    assert {:horizontal, 5.45} == state.width

    {:vertical, height} = state.height
    assert_in_delta height, 1223.22, 0.1

    assert {:vertical, frame_size} = state.frame_size
    assert {:vertical, 2234.75} == state.content_size
    assert {:vertical, 1.436} == state.scroll_position
    assert {:vertical, 1.436} == state.last_scroll_position
    assert :vertical == state.direction
    assert %Scenic.Scrollable.Drag{
      enabled_buttons: [:left, :right],
      drag_state: :idle,
      drag_start_content_position: :none,
      drag_start: :none,
      current: :none
    } == state.drag_state

    %Scenic.Scrollable.PositionCap{
      max: {:some, {0, max}},
      min: {:some, {0, min}}
    } = state.position_cap
    assert_in_delta max, 553.15, 0.1
    assert min == 5.45

    assert {
      :some,
      %{
        scroll_button_1: :released,
        scroll_button_2: :released
      }
    } == state.scroll_buttons
    assert :released == state.scroll_bar_slider_background
    assert :idle == state.scroll_state
    assert [
      font: :roboto,
      font_size: 24,
      scroll_bar_border: 1,
      scroll_bar_radius: 4,
      scroll_bar_theme: Theme.preset(:dark),
      scroll_buttons: true,
      scroll_drag: %{
        mouse_buttons: [:left, :right]
      }
    ] == state.styles

    assert TestParentScene.has_event_fired?(:scroll_bar_initialized)

    stop.(pid)
  end

  test "direction default", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_1)

    assert ScrollBar.direction(state) == {0, 0}

    stop.(pid)
  end

  test "horizontal direction", %{start: start, stop: stop} do
    {:ok, {pid, _state}} = start.(:case_3)

    ScrollBar.simulate_left_button_press(pid, {0, 0}, :scroll_button_1)
    {:ok, {pid, state}} = ScrollBar.inspect(pid)

    assert ScrollBar.direction(state) == {1, 0}
    assert ScrollBar.direction(pid) == {1, 0}

    ScrollBar.simulate_left_button_release(pid, {0, 0}, :scroll_button_1)
    {:ok, {pid, state}} = ScrollBar.inspect(pid)

    assert ScrollBar.direction(state) == {0, 0}
    assert ScrollBar.direction(pid) == {0, 0}

    stop.(pid)
  end

  test "vertical direction", %{start: start, stop: stop} do
    {:ok, {pid, _state}} = start.(:case_2)

    ScrollBar.simulate_left_button_press(pid, {0, 0}, :scroll_button_1)
    {:ok, {pid, state}} = ScrollBar.inspect(pid)

    assert ScrollBar.direction(state) == {0, 1}
    assert ScrollBar.direction(pid) == {0, 1}

    ScrollBar.simulate_left_button_release(pid, {0, 0}, :scroll_button_1)
    {:ok, {pid, state}} = ScrollBar.inspect(pid)

    assert ScrollBar.direction(state) == {0, 0}
    assert ScrollBar.direction(pid) == {0, 0}

    stop.(pid)
  end

  test "dragging? default", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_1)

    assert not ScrollBar.dragging?(state)

    stop.(pid)
  end

  test "dragging?", %{start: start, stop: stop} do
    {:ok, {pid, _state}} = start.(:case_2)

    ScrollBar.simulate_left_button_press(pid, {0, 0}, :scroll_bar_slider_drag_control)
    ScrollBar.simulate_mouse_move(pid, {1, 0}, :input_capture)

    assert {:ok, true} = wait_until_true(fn ->
      {:ok, {_pid, state}} = ScrollBar.inspect(pid)
      ScrollBar.dragging?(state)
    end)

    stop.(pid)
  end

  test "new_position default", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_1)

    assert ScrollBar.new_position(state) == {0, 0}

    stop.(pid)
  end

  test "new_position by slider drag", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_2)

    assert ScrollBar.new_position(state) == {0, 1.436}

    ScrollBar.simulate_left_button_press(pid, {0, 0}, :scroll_bar_slider_drag_control)
    ScrollBar.simulate_mouse_move(pid, {0, 1}, :input_capture)

    assert {:ok, true} = wait_until_true(fn ->
      {:ok, {_pid, state}} = ScrollBar.inspect(pid)
      {x, y} = ScrollBar.new_position(state)

      y > -1.85 && y < -1.8 && x == 0
    end)

    stop.(pid)
  end

  test "new_position by background click", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_2)

    assert ScrollBar.new_position(state) == {0, 1.436}

    ScrollBar.simulate_left_button_press(pid, {0, 349}, :scroll_bar_slider_background)
    ScrollBar.simulate_left_button_release(pid, {0, 350}, :scroll_bar_slider_background)

    assert {:ok, true} = wait_until_true(fn ->
      {:ok, {_pid, state}} = ScrollBar.inspect(pid)
      {x, y} = ScrollBar.new_position(state)

      y > -12.5 && y < -12.4 && x == 0
    end)

    stop.(pid)
  end

  test "update scroll position", %{start: start, stop: stop} do
    {:ok, {pid, _}} = start.(:case_2)

    GenServer.call(pid, {:update_scroll_position, 5})
    {:ok, {pid, state}} = ScrollBar.inspect(pid)

    assert {0, 5} == ScrollBar.new_position(state)

    stop.(pid)
  end

  test "cursor exit", %{start: start, stop: stop} do
    {:ok, {pid, _}} = start.(:case_2)

    ScrollBar.simulate_left_button_press(pid, {0, 0}, :scroll_button_1)
    {:ok, {pid, state}} = ScrollBar.inspect(pid)

    assert ScrollBar.direction(state) == {0, 1}

    ScrollBar.simulate_mouse_exit(pid, :scroll_button_1)
    {:ok, {pid, state}} = ScrollBar.inspect(pid)

    assert ScrollBar.direction(state) == {0, 0}

    stop.(pid)
  end

  defp wait_until_true(assertion, timeout \\ 5000), do: wait_until_true(assertion, 0, timeout)

  defp wait_until_true(assertion, time_passed, timeout) do
    case {assertion.(), time_passed < timeout} do
      {true, _} ->
        {:ok, true}
      {_, false} ->
        {:error, :timeout}
      _ ->
        :timer.sleep(100)
        wait_until_true(assertion, time_passed + 100, timeout)
    end
  end

end
