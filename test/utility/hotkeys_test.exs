defmodule Scenic.Scrollable.HotkeysTest do
  use ExUnit.Case
  doctest Scenic.Scrollable.Hotkeys
  alias Scenic.Scrollable.Hotkeys

  setup_all context do
    {:ok, Map.put(context, :default, %Hotkeys{})}
  end

  test "init", %{default: default} do
    assert Hotkeys.init(nil) == default

    assert Hotkeys.init(%{up: "u", down: "d"}) == %{
             default
             | key_map: %{
                 up: {:some, "U"},
                 down: {:some, "D"},
                 left: :none,
                 right: :none
               }
           }

    assert Hotkeys.init(%{left: "left", right: "RIGHT"}) == %{
             default
             | key_map: %{
                 up: :none,
                 down: :none,
                 left: {:some, "left"},
                 right: {:some, "right"}
               }
           }
  end

  test "handle_key_press", %{default: default} do
    assert Hotkeys.handle_key_press(default, "up") == default

    state = Hotkeys.init(%{up: "up"})

    assert Hotkeys.handle_key_press(state, "up") == %{
             state
             | key_pressed_states: %{
                 up: :pressed,
                 down: :released,
                 left: :released,
                 right: :released
               }
           }

    state = Hotkeys.init(%{down: "s"})

    assert Hotkeys.handle_key_press(state, "S") == %{
             state
             | key_pressed_states: %{
                 up: :released,
                 down: :pressed,
                 left: :released,
                 right: :released
               }
           }

    state =
      Hotkeys.init(%{left: "a", right: "d"})
      |> Hotkeys.handle_key_press("A")
      |> Hotkeys.handle_key_press("D")

    assert state == %{
             default
             | key_map: %{left: {:some, "A"}, right: {:some, "D"}, down: :none, up: :none},
               key_pressed_states: %{
                 up: :released,
                 down: :released,
                 left: :pressed,
                 right: :pressed
               }
           }
  end

  test "handle_key_release", %{default: default} do
    assert Hotkeys.handle_key_release(default, "left") == default

    state =
      Hotkeys.init(%{left: "a"})
      |> Hotkeys.handle_key_press("A")

    assert Hotkeys.handle_key_release(state, "A") == %{
             state
             | key_pressed_states: default.key_pressed_states
           }

    state =
      Hotkeys.init(%{left: "a", right: "d"})
      |> Hotkeys.handle_key_press("A")
      |> Hotkeys.handle_key_press("D")

    assert Hotkeys.handle_key_release(state, "D") == %{
             state
             | key_pressed_states: %{
                 up: :released,
                 down: :released,
                 left: :pressed,
                 right: :released
               }
           }
  end

  test "direction", %{default: default} do
    assert Hotkeys.direction(default) == {0, 0}

    assert Hotkeys.direction(Map.update!(default, :key_pressed_states, &%{&1 | up: :pressed})) ==
             {0, 1}

    assert Hotkeys.direction(Map.update!(default, :key_pressed_states, &%{&1 | down: :pressed})) ==
             {0, -1}

    assert Hotkeys.direction(Map.update!(default, :key_pressed_states, &%{&1 | right: :pressed})) ==
             {1, 0}

    assert Hotkeys.direction(Map.update!(default, :key_pressed_states, &%{&1 | left: :pressed})) ==
             {-1, 0}

    assert Hotkeys.direction(
             Map.update!(default, :key_pressed_states, &%{&1 | up: :pressed, down: :pressed})
           ) == {0, 0}

    assert Hotkeys.direction(
             Map.update!(default, :key_pressed_states, &%{&1 | left: :pressed, right: :pressed})
           ) == {0, 0}

    assert Hotkeys.direction(
             Map.update!(default, :key_pressed_states, &%{&1 | up: :pressed, right: :pressed})
           ) == {1, 1}

    assert Hotkeys.direction(
             Map.update!(default, :key_pressed_states, &%{&1 | down: :pressed, left: :pressed})
           ) == {-1, -1}
  end
end
