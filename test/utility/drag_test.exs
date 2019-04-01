defmodule Scenic.Scrollable.DragTest do
  use ExUnit.Case
  doctest Scenic.Scrollable.Drag
  alias Scenic.Scrollable.Drag

  setup_all context do
    {:ok, Map.put(context, :default, %Drag{})}
  end

  test "init", %{default: default} do
    assert Drag.init(nil) == default
    assert Drag.init(%{}) == default
    assert Drag.init(%{mouse_buttons: []}) == default

    state = Drag.init(%{mouse_buttons: [:left]})
    assert state == %{default | enabled_buttons: [:left]}

    state = Drag.init(%{mouse_buttons: [:right]})
    assert state == %{default | enabled_buttons: [:right]}

    state = Drag.init(%{mouse_buttons: [:middle]})
    assert state == %{default | enabled_buttons: [:middle]}

    state = Drag.init(%{mouse_buttons: [:left, :right]})
    assert state == %{default | enabled_buttons: [:left, :right]}

    state = Drag.init(%{mouse_buttons: [:left, :right, :middle]})
    assert state == %{default | enabled_buttons: [:left, :right, :middle]}
  end

  test "dragging?", %{default: default} do
    assert Drag.dragging?(default) == false
    assert Drag.dragging?(%{default | drag_state: :dragging}) == true
  end

  test "new_position", %{default: default} do
    assert Drag.new_position(default) == :none

    state = %{
      default
      | drag_state: :dragging,
        drag_start_content_position: {:some, {0, 0}},
        drag_start: {:some, {0, 0}},
        current: {:some, {0, 0}}
    }

    assert Drag.new_position(state) == {:some, {0, 0}}

    state = %{
      default
      | drag_state: :dragging,
        drag_start_content_position: {:some, {1, 2}},
        drag_start: {:some, {2, 3}},
        current: {:some, {3, 4}}
    }

    assert Drag.new_position(state) == {:some, {2, 3}}
  end

  test "last_position", %{default: default} do
    assert Drag.last_position(default) == :none
    assert Drag.last_position(%{default | current: {:some, {0, 0}}}) == {:some, {0, 0}}

    assert Drag.last_position(%{default | current: {:some, {324_645, 3456}}}) ==
             {:some, {324_645, 3456}}
  end

  test "handle_mouse_click", %{default: default} do
    assert Drag.handle_mouse_click(default, :left, {0, 0}, {0, 0}) == default

    state = %{default | enabled_buttons: [:left]}

    assert Drag.handle_mouse_click(state, :left, {1, 1}, {2, 2}) == %{
             state
             | drag_state: :dragging,
               drag_start_content_position: {:some, {2, 2}},
               drag_start: {:some, {1, 1}},
               current: {:some, {1, 1}}
           }

    state = %{default | enabled_buttons: [:left, :right]}

    assert Drag.handle_mouse_click(state, :right, {1, 1}, {2, 2}) == %{
             state
             | drag_state: :dragging,
               drag_start_content_position: {:some, {2, 2}},
               drag_start: {:some, {1, 1}},
               current: {:some, {1, 1}}
           }

    state = %{default | enabled_buttons: [:middle, :right]}

    assert Drag.handle_mouse_click(state, :middle, {1, 1}, {2, 2}) == %{
             state
             | drag_state: :dragging,
               drag_start_content_position: {:some, {2, 2}},
               drag_start: {:some, {1, 1}},
               current: {:some, {1, 1}}
           }

    state = %{default | enabled_buttons: [:middle, :right]}

    assert Drag.handle_mouse_click(state, :left, {1, 1}, {2, 2}) == state
  end

  test "handle_mouse_move", %{default: default} do
    assert Drag.handle_mouse_move(default, {1, 2}) == default

    state = %{default | drag_state: :scrolling}
    assert Drag.handle_mouse_move(state, {1, 2}) == %{state | current: {:some, {1, 2}}}
  end

  test "handle_mouse_release", %{default: default} do
    assert Drag.handle_mouse_release(default, :left, {1, 1}) == default

    state = %{default | enabled_buttons: [:left]}
    state = Drag.handle_mouse_click(state, :left, {1, 1}, {2, 2})

    assert Drag.handle_mouse_release(state, :left, {3, 3}) == %{
             state
             | drag_state: :idle,
               current: :none
           }
  end

  test "amplify_speed", %{default: default} do
    assert Drag.amplify_speed(default, {1, 2}) == {3, 6}
  end
end
