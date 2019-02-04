defmodule Scenic.Scrollable.Drag do
  @moduledoc """
  Module for handling the drag controllability for `Scenic.Scrollable` components.
  """

  alias Scenic.Math.Vector2
  alias Scenic.Math

  @typedoc """
  Atom representing a mouse button.
  """
  @type mouse_button :: :left | :right | :middle

  @typedoc """
  Data structure with settings that dictate the behaviour of the drag controllability.
  It consists of a list with `t:Scenic.Scrollable.Drag.mouse_button/0`s which specify the buttons with which the user can drag the `Scenic.Scrollable` component.
  By default, drag functionality is disabled.
  """
  @type drag_settings :: [mouse_button]

  @typedoc """
  Shorthand for `t:Scenic.Math.vector_2/0`.
  Consists of a tuple containing the x and y numeric values.
  """
  @type v2 :: Math.vector_2()

  @typedoc """
  Atom representing what state the drag functionality is currently in.
  The drag state can be 'idle' or 'dragging'.
  """
  @type drag_state :: :idle | :dragging

  @typedoc """
  The state containing the necessary information to enable the drag functionality.
  """
  @type t :: %__MODULE__{
          enabled_buttons: [mouse_button],
          drag_state: drag_state,
          drag_start_content_position: :none | {:some, v2},
          drag_start: :none | {:some, v2},
          current: :none | {:some, v2}
        }

  defstruct enabled_buttons: [],
            drag_state: :idle,
            drag_start_content_position: :none,
            drag_start: :none,
            current: :none

  # This constant specifies the factor with which the speed based on the last drag distance is multiplied after the drag has ended. This is to make the drag scroll experience feel more smooth.
  @drag_stop_speed_amplifier 3

  @doc """
  Initialize the `t:Scenic.Scrollable.Drag.t/0` state by passing in the `t:Scenic.Scrollable.Drag.drag_settings/0` settings object.
  When nil is passed, the default settings will be used.
  """
  @spec init(nil | drag_settings) :: t
  def init(nil) do
    %__MODULE__{}
  end

  def init(drag_settings) do
    %__MODULE__{
      enabled_buttons: drag_settings
    }
  end

  @doc """
  Find out if the user is currently dragging the `Scenic.Scrollable` component.
  """
  @spec dragging?(t) :: boolean
  def dragging?(%{drag_state: :idle}), do: false

  def dragging?(%{drag_state: :dragging}), do: true

  @doc """
  Calculate the new scroll position based on the current drag state.
  The result will be wrapped in an `t:OptionEx.t/0`, resulting in :none if the user currently is not scrolling.
  """
  @spec new_position(t) :: {:some, v2} | :none
  def new_position(%{
        drag_state: :dragging,
        drag_start_content_position: {:some, drag_start_content_position},
        drag_start: {:some, drag_start},
        current: {:some, current}
      }) do
    current
    |> Vector2.sub(drag_start)
    |> Vector2.add(drag_start_content_position)
    |> OptionEx.return()
  end

  def new_position(_), do: :none

  @doc """
  Get the position of the users cursor during the previous update.
  Returns an `t:OptionEx.t/0` containing the coordinate, or :none if the user was not dragging during the previous update.
  """
  @spec last_position(t) :: {:some, v2} | :none
  def last_position(%{current: current}), do: current

  @doc """
  Update the `t:Scenic.Scrollable.Drag.t/0` based on the pressed mouse button, mouse position, and the position of the scrollable content.
  """
  @spec handle_mouse_click(t, mouse_button, v2, v2) :: t
  def handle_mouse_click(state, button, point, content_position) do
    if Enum.member?(state.enabled_buttons, button),
      do: start_drag(state, point, content_position),
      else: state
  end

  @doc """
  Update the `t:Scenic.Scrollable.Drag.t/0` based on the new cursor position the user has moved to.
  """
  @spec handle_mouse_move(t, v2) :: t
  def handle_mouse_move(%{drag_state: :idle} = state, _), do: state

  def handle_mouse_move(state, point), do: drag(state, point)

  @doc """
  Update the `t:Scenic.Scrollable.Drag.t/0` based on the released mouse button and mouse position.
  """
  @spec handle_mouse_release(t, mouse_button, v2) :: t
  def handle_mouse_release(state, button, point) do
    if Enum.member?(state.enabled_buttons, button), do: stop_drag(state, point), else: state
  end

  @doc """
  Increases the current scroll speed, intended to be called when the user stops dragging.
  The increase in speed is intended to make the drag experience more smooth.
  """
  @spec amplify_speed(t, v2) :: v2
  def amplify_speed(_, speed), do: Vector2.mul(speed, @drag_stop_speed_amplifier)

  # Update the `t:Scenic.Scrollable.Drag.t` state with the necessary positional and status defining values when the user starts dragging.
  @spec start_drag(t, v2, v2) :: t
  defp start_drag(state, point, content_position) do
    state
    |> Map.put(:drag_state, :dragging)
    |> Map.put(:drag_start_content_position, {:some, content_position})
    |> Map.put(:drag_start, {:some, point})
    |> Map.put(:current, {:some, point})
  end

  # Update the `t:Scenic.Scrollable.Drag.t` with the necessary positional values when the user procs a mouse move event while dragging.
  @spec drag(t, v2) :: t
  defp drag(state, point) do
    state
    |> Map.put(:current, {:some, point})
  end

  # Update the `t:Scenic.Scrollable.Drag.t` with the necessary state defining values when the user stops dragging.
  @spec stop_drag(t, v2) :: t
  defp stop_drag(state, _) do
    state
    |> Map.put(:drag_state, :idle)
    |> Map.put(:current, :none)
  end
end
