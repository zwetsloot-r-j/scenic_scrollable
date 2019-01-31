defmodule Scenic.Scrollable.Hotkeys do
  @type keycode :: String.t()

  @type hotkey_settings :: %{
          optional(:up) => keycode,
          optional(:down) => keycode,
          optional(:left) => keycode,
          optional(:right) => keycode
        }

  @type key_map :: %{
          up: :none | {:some, keycode},
          down: :none | {:some, keycode},
          left: :none | {:some, keycode},
          right: :none | {:some, keycode}
        }

  @type key_pressed_state :: :released | :pressed

  @type key_pressed_states :: %{
          up: key_pressed_state,
          down: key_pressed_state,
          left: key_pressed_state,
          right: key_pressed_state
        }

  @type t :: %__MODULE__{
          key_map: key_map,
          key_pressed_states: key_pressed_states
        }

  defstruct key_map: %{
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

  def init(nil), do: %__MODULE__{}

  def init(hotkey_settings) do
    %__MODULE__{
      key_map: %{
        up: parse_keycode(hotkey_settings[:up]),
        down: parse_keycode(hotkey_settings[:down]),
        left: parse_keycode(hotkey_settings[:left]),
        right: parse_keycode(hotkey_settings[:right])
      }
    }
  end

  def handle_key_press(%{key_map: %{up: up, down: down, left: left, right: right}} = state, key) do
    case {:some, key} do
      ^up -> press(state, :up)
      ^down -> press(state, :down)
      ^left -> press(state, :left)
      ^right -> press(state, :right)
      _ -> state
    end
  end

  def handle_key_release(%{key_map: %{up: up, down: down, left: left, right: right}} = state, key) do
    case {:some, key} do
      ^up -> release(state, :up)
      ^down -> release(state, :down)
      ^left -> release(state, :left)
      ^right -> release(state, :right)
      _ -> state
    end
  end

  def direction(%{key_pressed_states: pressed_states}) do
    x =
      case pressed_states do
        %{left: :pressed, right: :released} -> -1
        %{left: :released, right: :pressed} -> 1
        _ -> 0
      end

    y =
      case pressed_states do
        %{up: :pressed, down: :released} -> 1
        %{up: :released, down: :pressed} -> -1
        _ -> 0
      end

    {x, y}
    |> IO.inspect(label: "direction")
  end

  defp press(state, key) do
    %{state | key_pressed_states: Map.put(state.key_pressed_states, key, :pressed)}
  end

  defp release(state, key) do
    %{state | key_pressed_states: Map.put(state.key_pressed_states, key, :released)}
  end

  defp parse_keycode(keycode) do
    keycode
    |> OptionEx.return()
    |> OptionEx.map(&upcase_single_char/1)
  end

  defp upcase_single_char(keycode) do
    if String.length(keycode) == 1 do
      String.upcase(keycode)
    else
      String.downcase(keycode)
    end
  end
end
