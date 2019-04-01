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
        scroll_position: {-1, -2},
        scroll_acceleration: %{
          acceleration: 12,
          mass: 1.1,
          counter_pressure: 0.2
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

      graph =
        Components.scrollable(
          graph,
          settings[case_number],
          builders[case_number],
          styles[case_number]
        )

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

    assert Scrollable.verify(%{content: %{x: 1, y: 2, width: 3, height: 4}, frame: {3, 4}}) ==
             :invalid_input

    settings = %{content: {1, 2}, frame: {3, 4}, builder: fn -> :ok end}
    assert Scrollable.verify(settings) == {:ok, settings}

    settings = %{
      content: %{x: 1, y: 2, width: 3, height: 4},
      frame: {3, 4},
      builder: fn -> :ok end
    }

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

  test "init case 2", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_2)

    assert %Scrollable{} = state
    assert %Graph{} = state.graph
    assert %{x: 0, y: 0, width: 50.123, height: 60.321} == state.frame
    assert %{x: 12.34, y: 45.67, width: 123.45, height: 678.9} == state.content
    assert {11.34, 43.67} == state.scroll_position
    assert 60 == state.fps

    assert %Acceleration{
             acceleration: 12,
             mass: 1.1,
             counter_pressure: 0.2,
             force: {0, 0},
             speed: {0, 0}
           } == state.acceleration

    assert %Hotkeys{
             key_map: %{
               up: {:some, "W"},
               down: {:some, "S"},
               left: {:some, "A"},
               right: {:some, "D"}
             },
             key_pressed_states: %{
               up: :released,
               down: :released,
               left: :released,
               right: :released
             }
           } == state.hotkeys

    assert %Drag{
             enabled_buttons: [:left, :middle, :right],
             drag_state: :idle,
             drag_start_content_position: :none,
             drag_start: :none,
             current: :none
           } == state.drag_state

    %PositionCap{
      min: {:some, {min_x, min_y}},
      max: {:some, max}
    } = state.position_caps

    assert_in_delta min_x, -61, 0.1
    assert_in_delta min_y, -572.91, 0.1
    assert {12.34, 45.67} == max
    assert not state.focused
    assert not state.animating

    assert {:ok, true} =
             wait_until_true(fn ->
               case state.scroll_bars do
                 {:some, %ScrollBars{}} -> true
                 _ -> false
               end
             end)

    stop.(pid)
  end

  test "handle_input left mouse button", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_2)

    # test input is not being captured
    Scrollable.simulate_key_press(pid, "W", :input_capture)
    assert {0, 0} = Hotkeys.direction(state.hotkeys)
    Scrollable.simulate_key_release(pid, "W", :input_capture)

    Scrollable.simulate_left_button_press(pid, {0, 0}, state.id)
    Scrollable.simulate_left_button_release(pid, {0, 0}, state.id)
    {:ok, {pid, state}} = Scrollable.inspect(pid)

    assert state.focused

    # test input is being captured
    Scrollable.simulate_key_press(pid, "W", :input_capture)
    assert {0, 1} = Hotkeys.direction(state.hotkeys)
    Scrollable.simulate_key_release(pid, "W", :input_capture)

    stop.(pid)
  end

  test "handle_input drag disabled", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_1)
    content_translation = get_content_translation(state)

    assert not Drag.dragging?(state.drag_state)

    Scrollable.simulate_left_button_press(pid, {0, 0}, state.id)
    Scrollable.simulate_mouse_move(pid, {0, 1}, state.id)
    {:ok, {pid, state}} = Scrollable.inspect(pid)

    assert not Drag.dragging?(state.drag_state)
    assert content_translation == get_content_translation(state)

    Scrollable.simulate_left_button_release(pid, {0, 1}, state.id)
    {:ok, {pid, state}} = Scrollable.inspect(pid)

    assert not Drag.dragging?(state.drag_state)

    stop.(pid)
  end

  test "handle_input drag enabled", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_2)
    content_translation = get_content_translation(state)

    assert not Drag.dragging?(state.drag_state)

    Scrollable.simulate_left_button_press(pid, {0, 0}, state.id)
    Scrollable.simulate_mouse_move(pid, {0, -100}, state.id)
    {:ok, {pid, state}} = Scrollable.inspect(pid)

    assert Drag.dragging?(state.drag_state)
    assert content_translation != get_content_translation(state)

    Scrollable.simulate_left_button_release(pid, {0, 1}, state.id)
    {:ok, {pid, state}} = Scrollable.inspect(pid)

    assert not Drag.dragging?(state.drag_state)

    stop.(pid)
  end

  test "handle_input key scroll up", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_2)
    {content_translation_x, content_translation_y} = get_content_translation(state)

    Scrollable.simulate_key_press(pid, "W", :input_capture)

    assert {:ok, true} =
             wait_until_true(fn ->
               {:ok, {_pid, state}} = Scrollable.inspect(pid)
               {new_x, new_y} = get_content_translation(state)
               new_x == content_translation_x && new_y > content_translation_y
             end)

    Scrollable.simulate_key_release(pid, "W", :input_capture)

    stop.(pid)
  end

  test "handle_input key scroll down", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_2)
    {content_translation_x, content_translation_y} = get_content_translation(state)

    Scrollable.simulate_key_press(pid, "S", :input_capture)

    assert {:ok, true} =
             wait_until_true(fn ->
               {:ok, {_pid, state}} = Scrollable.inspect(pid)
               {new_x, new_y} = get_content_translation(state)
               new_x == content_translation_x && new_y < content_translation_y
             end)

    Scrollable.simulate_key_release(pid, "S", :input_capture)

    stop.(pid)
  end

  test "handle_input key scroll left", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_2)
    {content_translation_x, content_translation_y} = get_content_translation(state)

    Scrollable.simulate_key_press(pid, "A", :input_capture)

    assert {:ok, true} =
             wait_until_true(fn ->
               {:ok, {_pid, state}} = Scrollable.inspect(pid)
               {new_x, new_y} = get_content_translation(state)
               new_x < content_translation_x && new_y == content_translation_y
             end)

    Scrollable.simulate_key_release(pid, "A", :input_capture)

    stop.(pid)
  end

  test "handle_input key scroll right", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_2)
    {content_translation_x, content_translation_y} = get_content_translation(state)

    Scrollable.simulate_key_press(pid, "D", :input_capture)

    assert {:ok, true} =
             wait_until_true(fn ->
               {:ok, {_pid, state}} = Scrollable.inspect(pid)
               {new_x, new_y} = get_content_translation(state)
               new_x > content_translation_x && new_y == content_translation_y
             end)

    Scrollable.simulate_key_release(pid, "D", :input_capture)

    stop.(pid)
  end

  test "handle_input key scroll up left", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_2)
    {content_translation_x, content_translation_y} = get_content_translation(state)

    Scrollable.simulate_key_press(pid, "W", :input_capture)
    Scrollable.simulate_key_press(pid, "D", :input_capture)

    assert {:ok, true} =
             wait_until_true(fn ->
               {:ok, {_pid, state}} = Scrollable.inspect(pid)
               {new_x, new_y} = get_content_translation(state)
               new_x > content_translation_x && new_y > content_translation_y
             end)

    Scrollable.simulate_key_release(pid, "W", :input_capture)
    Scrollable.simulate_key_release(pid, "D", :input_capture)

    stop.(pid)
  end

  test "handle_input key scroll down right", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_2)
    {content_translation_x, content_translation_y} = get_content_translation(state)

    Scrollable.simulate_key_press(pid, "S", :input_capture)
    Scrollable.simulate_key_press(pid, "A", :input_capture)

    assert {:ok, true} =
             wait_until_true(fn ->
               {:ok, {_pid, state}} = Scrollable.inspect(pid)
               {new_x, new_y} = get_content_translation(state)
               new_x < content_translation_x && new_y < content_translation_y
             end)

    Scrollable.simulate_key_release(pid, "S", :input_capture)
    Scrollable.simulate_key_release(pid, "A", :input_capture)

    stop.(pid)
  end

  test "handle_input key scroll down up", %{start: start, stop: stop} do
    {:ok, {pid, _state}} = start.(:case_2)

    Scrollable.simulate_key_press(pid, "W", :input_capture)
    Scrollable.simulate_key_press(pid, "S", :input_capture)

    # MEMO there will be a slight movement lingering from the first button press
    # this is hardly noticable in practice, so I will have the test go along with it
    assert {:ok, true} =
             wait_until_true(fn ->
               {:ok, {_pid, state}} = Scrollable.inspect(pid)
               state.scrolling == :idle
             end)

    {:ok, {pid, state}} = Scrollable.inspect(pid)
    content_translation = get_content_translation(state)

    :timer.sleep(100)

    {:ok, {pid, state}} = Scrollable.inspect(pid)
    assert content_translation == get_content_translation(state)

    Scrollable.simulate_key_release(pid, "W", :input_capture)
    Scrollable.simulate_key_release(pid, "S", :input_capture)

    stop.(pid)
  end

  test "handle_input cooldown after drag", %{start: start, stop: stop} do
    {:ok, {pid, state}} = start.(:case_2)

    Scrollable.simulate_left_button_press(pid, {0, 0}, state.id)
    Scrollable.simulate_mouse_move(pid, {0, -50}, state.id)
    Scrollable.simulate_left_button_release(pid, {0, -100}, state.id)
    {:ok, {pid, state}} = Scrollable.inspect(pid)

    assert state.scrolling == :cooling_down

    content_translation = get_content_translation(state)

    # assert the content is still moving
    assert {:ok, true} =
             wait_until_true(fn ->
               {:ok, {_pid, state}} = Scrollable.inspect(pid)
               content_translation != get_content_translation(state)
             end)

    stop.(pid)
  end

  defp get_content_translation(state) do
    Graph.get!(state.graph, :content)
    |> Map.fetch(:transforms)
    |> ResultEx.bind(&Map.fetch(&1, :translate))
    |> ResultEx.or_else({0, 0})
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
