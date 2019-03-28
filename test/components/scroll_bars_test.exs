defmodule Scenic.Scrollable.ScrollBarsTest do
  use ExUnit.Case, async: false
  doctest Scenic.Scrollable.ScrollBars
  alias Scenic.Scrollable.ScrollBars
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
    }

    styles = %{
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
    }

    start = fn case_number ->
      {:ok, {parent_pid, _}} = TestParentScene.inspect()

      graph = Components.scroll_bars(graph, settings[case_number], styles[case_number])
      TestParentScene.set_graph(parent_pid, graph)
      ScrollBars.inspect_until_found()
    end

    stop = fn pid ->
      {:ok, {parent_pid, _}} = TestParentScene.inspect()

      TestParentScene.set_graph(parent_pid, Graph.build())
      TestParentScene.clear_event_history(parent_pid)
      ScrollBars.wait_until_destroyed(pid)
    end

    Map.put(context, :settings, settings)
    |> Map.put(:styles, styles)
    |> Map.put(:start, start)
    |> Map.put(:stop, stop)
    |> Map.put(:graph, graph)
  end

  test "init case 1", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_1)

    assert %ScrollBars{} = state
    assert %Graph{} = state.graph
    assert :none = state.horizontal_scroll_bar_pid
    assert :none = state.vertical_scroll_bar_pid
    assert :test_scroll_bars_case_1 == state.id
    assert is_pid(state.pid)
    assert {0, 0} == state.scroll_position
    assert :idle == state.scroll_state

    assert TestParentScene.has_event_fired?(:scroll_bars_initialized)

    stop.(pid)
  end

  test "init case 2", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_2)

    assert %ScrollBars{} = state
    assert %Graph{} = state.graph
    assert {:some, _} = state.horizontal_scroll_bar_pid
    assert {:some, _} = state.vertical_scroll_bar_pid
    assert :test_scroll_bars_case_2 == state.id
    assert is_pid(state.pid)
    assert {50, 25} == state.scroll_position
    assert :idle == state.scroll_state

    assert TestParentScene.has_event_fired?(:scroll_bars_initialized)

    stop.(pid)
  end

  test "verify" do
    assert ScrollBars.verify(%{}) == :invalid_input
    assert ScrollBars.verify(%{content_size: {1, 1}}) == :invalid_input
    assert ScrollBars.verify(%{scroll_position: {1, 1}}) == :invalid_input
    assert ScrollBars.verify(%{content_size: {1, 1}, scroll_position: {1, 1}}) == {:ok, %{content_size: {1, 1}, scroll_position: {1, 1}}}
    assert ScrollBars.verify(%{content_size: {"1", "1"}, scroll_position: {1, 1}}) == :invalid_input
    assert ScrollBars.verify(%{content_size: {1, 1}, scroll_position: {"1", "1"}}) == :invalid_input
  end

  test "default direction", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_1)

    assert ScrollBars.direction(state) == {0, 0}

    stop.(pid)
  end

  test "horizontal direction", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_2)
    {:some, horizontal_scroll_bar_pid} = state.horizontal_scroll_bar_pid

    ScrollBar.simulate_left_button_press(horizontal_scroll_bar_pid, {0, 0}, :scroll_button_1)

    assert ScrollBars.direction(state) == {1, 0}

    ScrollBar.simulate_left_button_release(horizontal_scroll_bar_pid, {0, 0}, :scroll_button_1)

    assert ScrollBars.direction(state) == {0, 0}

    stop.(pid)
  end

  test "vertical direction", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_2)
    {:some, vertical_scroll_bar_pid} = state.vertical_scroll_bar_pid

    ScrollBar.simulate_left_button_press(vertical_scroll_bar_pid, {0, 0}, :scroll_button_1)

    assert ScrollBars.direction(state) == {0, 1}

    ScrollBar.simulate_left_button_release(vertical_scroll_bar_pid, {0, 0}, :scroll_button_1)

    assert ScrollBars.direction(state) == {0, 0}

    stop.(pid)
  end

  test "dragging? default", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_1)

    assert not ScrollBars.dragging?(state)

    stop.(pid)
  end

  test "dragging?", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_2)
    {:some, horizontal_scroll_bar_pid} = state.horizontal_scroll_bar_pid

    ScrollBar.simulate_left_button_press(horizontal_scroll_bar_pid, {0, 0}, :scroll_bar_slider_drag_control)
    ScrollBar.simulate_mouse_move(horizontal_scroll_bar_pid, {1, 0}, :input_capture)

    assert {:ok, true} = wait_until_true(fn ->
      {:ok, {_pid, state}} = ScrollBars.inspect(pid)
      ScrollBars.dragging?(state)
    end)

    stop.(pid)
  end

  test "new_position default", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_1)

    assert ScrollBars.new_position(state) == {:some, {0, 0}}

    stop.(pid)
  end

  test "new_position", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_2)

    assert ScrollBars.new_position(state) == {:some, {50, 25}}

    {:some, horizontal_scroll_bar_pid} = state.horizontal_scroll_bar_pid
    ScrollBar.simulate_left_button_press(horizontal_scroll_bar_pid, {0, 0}, :scroll_bar_slider_drag_control)
    ScrollBar.simulate_mouse_move(horizontal_scroll_bar_pid, {2, 0}, :input_capture)

    assert {:ok, true} = wait_until_true(fn ->
      {:ok, {_pid, state}} = ScrollBars.inspect(pid)
      {:some, {x, y}} = ScrollBars.new_position(state)

      x > -3.6 && x < -3.4 && y == 25
    end)

    stop.(pid)
  end

  test "update scroll position", %{start: start, stop: stop} do
    {:ok, {pid, _}} = start.(:case_2)

    GenServer.call(pid, {:update_scroll_position, {10, 5}})
    {:ok, {pid, state}} = ScrollBars.inspect(pid)

    assert {:some, {10, 5}} == ScrollBars.new_position(state)

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
