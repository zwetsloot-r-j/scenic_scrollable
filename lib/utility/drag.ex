defmodule Scenic.Scrollable.Drag do
  alias Scenic.Math.Vector2
  alias Scenic.Math

  @type mouse_button :: :left | :right | :middle

  @type drag_settings :: [mouse_button]

  @type v2 :: Math.vector_2()

  @type drag_state :: :idle | :dragging

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

  def init(nil) do
    %__MODULE__{}
  end

  def init(drag_settings) do
    %__MODULE__{
      enabled_buttons: drag_settings
    }
  end

  def dragging?(%{drag_state: :idle}), do: false

  def dragging?(%{drag_state: :dragging}), do: true

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

  def last_position(%{current: current}), do: current

  def handle_mouse_click(state, button, point, content_position) do
    if Enum.member?(state.enabled_buttons, button),
      do: start_drag(state, point, content_position),
      else: state
  end

  def handle_mouse_move(%{drag_state: :idle} = state, _), do: state

  def handle_mouse_move(state, point), do: drag(state, point)

  def handle_mouse_release(state, button, point) do
    if Enum.member?(state.enabled_buttons, button), do: stop_drag(state, point), else: state
  end

  defp start_drag(state, point, content_position) do
    state
    |> Map.put(:drag_state, :dragging)
    |> Map.put(:drag_start_content_position, {:some, content_position})
    |> Map.put(:drag_start, {:some, point})
    |> Map.put(:current, {:some, point})
  end

  defp drag(state, point) do
    state
    |> Map.put(:current, {:some, point})
  end

  defp stop_drag(state, _) do
    state
    |> Map.put(:drag_state, :idle)
    |> Map.put(:current, :none)
  end
end
