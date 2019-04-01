defmodule Scenic.Scrollable.Hotkeys do
  @moduledoc """
  This module handles key mappings and keypress events for `Scenic.Scrollable` components.
  """

  @typedoc """
  A keycode represented by a string.
  The string corresponds to the character as seen on the keyboard, rather than a numeric keycode.
  Special keys are generally spelled out in lower case characters, such as "enter" or "escape".
  """
  @type keycode :: String.t()

  @typedoc """
  The hotkey settings which can be passed in as style when creating a scrollable component.
  Hotkeys are optional and available for 'up', 'down', 'left' and 'right' scroll movements.
  """
  @type settings :: %{
          optional(:up) => keycode,
          optional(:down) => keycode,
          optional(:left) => keycode,
          optional(:right) => keycode
        }

  @typedoc """
  The keymap used internally to determine if, and what key is set for a certain movement.
  TODO support multiple keys for a single movement.
  """
  @type key_map :: %{
          up: :none | {:some, keycode},
          down: :none | {:some, keycode},
          left: :none | {:some, keycode},
          right: :none | {:some, keycode}
        }

  @typedoc """
  Button state containing information on if a key is currently pressed or released.
  """
  @type key_pressed_state :: :released | :pressed

  @typedoc """
  Data structure containing information on the pressed state of all available hotkeys.
  """
  @type key_pressed_states :: %{
          up: key_pressed_state,
          down: key_pressed_state,
          left: key_pressed_state,
          right: key_pressed_state
        }

  @typedoc """
  The data structure used as state by this module. It contains information on what keys are mapped to what functionality,
  and which keys are currently being pressed.
  """
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

  @doc """
  Initialize the state this module acts upon, by passing it the `t:Scenic.Scrollable.Hotkeys.settings/0` settings map.
  When nil is passed as argument, the default settings will be used.
  Returns a `t:Scenic.Scrollable.Hotkeys.t/0`.
  """
  @spec init(settings | nil) :: t
  def init(nil), do: %__MODULE__{}

  def init(settings) do
    %__MODULE__{
      key_map: %{
        up: parse_keycode(settings[:up]),
        down: parse_keycode(settings[:down]),
        left: parse_keycode(settings[:left]),
        right: parse_keycode(settings[:right])
      }
    }
  end

  @doc """
  Modifies the hotkey state accordingly to the key mappings and the keycode passed.
  When the passed keycode is set as one of the mapped keys, that key will be flagged as being pressed.
  """
  @spec handle_key_press(t, keycode) :: t
  def handle_key_press(%{key_map: %{up: up, down: down, left: left, right: right}} = state, key) do
    case {:some, key} do
      ^up -> press(state, :up)
      ^down -> press(state, :down)
      ^left -> press(state, :left)
      ^right -> press(state, :right)
      _ -> state
    end
  end

  @doc """
  Modifies the hotkey state accordingly to the key mappings and the keycode passed.
  When the passed keycode is set as one of the mapped keys, that key will be flagged as being released.
  """
  def handle_key_release(%{key_map: %{up: up, down: down, left: left, right: right}} = state, key) do
    case {:some, key} do
      ^up -> release(state, :up)
      ^down -> release(state, :down)
      ^left -> release(state, :left)
      ^right -> release(state, :right)
      _ -> state
    end
  end

  @doc """
  Obtain the current scroll direction based on the keys currently being pressed as a `t:Scenic.Math.vector_2`.
  For example, when the 'left' key and the 'up' key are currently being pressed, the vector {-1, 1} describing the corresponding direction will be returned.
  """
  @spec direction(t) :: Scenic.Math.vector_2()
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
  end

  @doc """
  Verify if one or more hotkeys are currently being pressed.
  """
  @spec is_any_key_pressed?(t) :: boolean
  def is_any_key_pressed?(%{key_pressed_states: pressed_states}) do
    pressed_states
    |> Map.values()
    |> Enum.any?(&(&1 == :pressed))
  end

  # Flags the key as pressed in the `t:Scrollable.Hotkeys.t` state.
  @spec press(t, :up | :down | :left | :right) :: t
  defp press(state, key) do
    %{state | key_pressed_states: Map.put(state.key_pressed_states, key, :pressed)}
  end

  # Flags the key as released in the `t:Scrollable.Hotkeys.t` state.
  @spec release(t, :up | :down | :left | :right) :: t
  defp release(state, key) do
    %{state | key_pressed_states: Map.put(state.key_pressed_states, key, :released)}
  end

  # Converts a keycode passed in as `t:Scrollable.Hotkeys.settings` to conform to the `Scenic` key press event key naming,
  # and wraps it in an `t:OptionEx.t` for internal use.
  @spec parse_keycode(keycode) :: {:some, keycode} | :none
  defp parse_keycode(keycode) do
    keycode
    |> OptionEx.return()
    |> OptionEx.map(&upcase_single_char/1)
  end

  # Converts single lower case characters to upper case,
  # and multiple character upper case strings to lower case,
  # to conform to the `Scenic` key press event naming.
  @spec upcase_single_char(keycode) :: keycode
  defp upcase_single_char(keycode) do
    if String.length(keycode) == 1 do
      String.upcase(keycode)
    else
      String.downcase(keycode)
    end
  end
end
