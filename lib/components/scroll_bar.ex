defmodule Scenic.Scrollable.ScrollBar do
  use Scenic.Component

  import Scenic.Primitives, only: [rrect: 3, rect: 3]
  import Scenic.Components, only: [button: 3]

  alias Scenic.Graph
  alias Scenic.Scrollable.Direction
  alias Scenic.Scrollable.Drag
  alias Scenic.Scrollable.PositionCap
  alias Scenic.Primitive.Style.Theme
  alias Scenic.Math.Vector2

  @type scroll_direction :: Direction.direction

  @type v2 :: Scenic.Scrollable.v2

  @type rect :: Scenic.Scrollable.rect

  @type settings :: %{
    width: number,
    height: number,
    content_size: number,
    scroll_position: number,
    direction: scroll_direction
  }

  @type t :: %{
    id: atom,
    graph: Graph.t,
    width: Direction.t,
    height: Direction.t,
    frame_size: Direction.t,
    content_size: Direction.t,
    scroll_position: Direction.t,
    direction: scroll_direction,
    drag_state: Drag.t,
    drag_button_clicked: boolean,
    position_cap: PositionCap.t,
    scroll_buttons: {:some, term} | :none,
    pid: pid
  }

  defstruct id: :scroll_bar,
    graph: nil,
    width: nil,
    height: nil,
    content_size: nil,
    frame_size: nil,
    scroll_position: nil,
    direction: nil,
    drag_state: %{},
    drag_button_clicked: false,
    position_cap: %{},
    scroll_buttons: :none,
    pid: nil

  @default_drag_settings [:left, :right, :middle]
  @default_button_radius 3
  @default_stroke_size 1
  @default_id :scroll_bar

  def init(%{width: width, height: height, content_size: content_size, direction: direction} = settings, opts) do
    styles = opts[:styles] || %{}
    scroll_buttons = opts[:scroll_buttons] || true # TODO make default false and pass as options

    %__MODULE__{
      id: opts[:id] || @default_id,
      graph: Graph.build(),
      content_size: Direction.return(content_size, direction),
      frame_size: Direction.from_vector_2({width, height}, direction),
      scroll_position: Direction.return(settings.scroll_position, direction),
      direction: direction,
      drag_state: Drag.init(styles[:scroll_drag_settings] || @default_drag_settings),
      scroll_buttons: OptionEx.from_bool(scroll_buttons, %{}),
      pid: self()
    }
    |> init_size(width, height)
    |> init_position_cap()
    |> init_graph()
    |> (fn state ->
      :ok = send_event({:scroll_bar_initialized, state.id, state})
      state
    end).()
    |> ResultEx.return
  end

  def verify(%{
    width: _,
    height: _,
    content_size: _,
    scroll_position: _,
    direction: _
  } = settings) do
    {:ok, settings}
  end

  def verify(_), do: :invalid_input

  def direction(_state) do
    {0, 0}
  end

  def dragging?(state), do: Drag.dragging?(state.drag_state)

  def new_position(state) do
    scroll_position_vector2(state)
  end

  def handle_input({:cursor_button, {button, :press, _, position}}, %{id: :scrollbar_slider_drag_control}, state) do
    state
    |> Map.update!(:drag_state, fn drag_state ->
      Drag.handle_mouse_click(drag_state, button, position, local_scroll_position_vector2(state))
    end)
    |> update_graph_component(:input_capture, fn primitive ->
      # TODO get screen res
      rect(primitive, {4000, 3000}, translate: {-2000, -1500})
    end)
    |> get_and_push_graph
    |> (&{:stop, &1}).()
  end

  def handle_input({:cursor_pos, position}, %{id: :input_capture}, state) do
    state
    |> Map.update!(:drag_state, fn drag_state ->
      Drag.handle_mouse_move(drag_state, position)
    end)
    |> update
    |> (&{:stop, &1}).()
  end

  def handle_input({:cursor_button, {button, :release, _, position}}, %{id: :input_capture}, state) do
    state
    |> Map.update!(:drag_state, fn drag_state ->
      Drag.handle_mouse_release(drag_state, button, position)
    end)
    |> update_graph_component(:input_capture, fn primitive ->
      rect(primitive, {0, 0}, translate: {0, 0})
    end)
    |> update
    |> (fn state ->
      :ok = send_event({:scroll_bar_scroll_end, state.id, state})
      state
    end).()
    |> (&{:stop, &1}).()
  end

  def handle_input({:cursor_button, {_button, :press, _, position}}, _, %{direction: direction} = state) do
    scroll_position = Direction.from_vector_2(position, direction)
                      |> Direction.map_horizontal(fn pos -> pos - button_width(state) / 2 end)
                      |> Direction.map_vertical(fn pos -> pos - button_height(state) / 2 end)

    scroll_position = local_to_world(state, scroll_position)

    state
    |> Map.put(:scroll_position, scroll_position)
    |> update
    |> (&{:stop, &1}).()
  end

  def handle_input(_event, _context, state) do
    {:stop, state}
  end

  def handle_call({:update_scroll_position, position}, _, state) do
    %{state | scroll_position: Direction.return(position, state.direction)}
    |> update_graph_drag_control_position
    |> get_and_push_graph
    |> (&{:reply, :ok, &1}).()
  end

  defp update(state) do
    state
    |> update_scroll_position
    |> update_graph_drag_control_position
    |> get_and_push_graph
    |> (fn state ->
      :ok = send_event({:scroll_bar_position_change, state.id, state})
      state
    end).()
  end

  defp update_graph_drag_control_position(state) do
    update_graph_component(state, :scrollbar_slider_drag_control, fn primitive ->
      Map.update(primitive, :transforms, %{}, fn transforms ->
        Map.put(transforms, :translate, local_scroll_position_vector2(state))
      end)
    end)
  end

  defp update_graph(state, updater) do
    state
    |> Map.update!(:graph, updater)
  end

  defp update_graph_component(state, id, updater) do
    update_graph(state, fn graph ->
      Graph.modify(graph, id, updater)
    end)
  end

  defp get_and_push_graph(%{graph: graph} = state) do
    push_graph(graph)
    state
  end

  defp init_size(%{scroll_buttons: :none} = state, width, height) do
    state
    |> Map.put(:width, Direction.as_horizontal(width))
    |> Map.put(:height, Direction.as_vertical(height))
  end

  defp init_size(%{scroll_buttons: {:some, _}} = state, width, height) do
    width = Direction.as_horizontal(width)
    height = Direction.as_vertical(height)

    displacement = scroll_bar_displacement(
                     state
                     |> Map.put(:width, width)
                     |> Map.put(:height, height)
                   )

    button_size_difference = Direction.map(displacement, & &1 * 2)

    state
    |> Map.put(:width, Direction.subtract(width, button_size_difference))
    |> Map.put(:height, Direction.subtract(height, button_size_difference))
  end

  defp scroll_bar_displacement(%{direction: direction} = state) do
    scroll_button_size(state)
    |> Direction.return(direction)
  end

  defp init_scroll_buttons(%{scroll_buttons: :none} = state), do: state
  defp init_scroll_buttons(%{graph: graph, direction: direction} = state) do
    {btn1_text, btn2_text} = Direction.return({"", ""}, direction)
                             |> Direction.map_horizontal(fn {left, right} -> {left <> "<", right <> ">"} end)
                             |> Direction.map_vertical(fn {up, down} -> {up <> "^", down <> "v"} end)
                             |> Direction.unwrap

    size = scroll_button_size(state)

    button_2_position = Direction.return(size, direction)
                        |> Direction.add(state.width)
                        |> Direction.add(state.height)
                        |> Direction.to_vector_2

    graph
    |> button(btn1_text, width: size, height: size, translate: {0, 0}, id: :scroll_button_1)
    |> button(btn2_text, width: size, height: size, translate: button_2_position, id: :scroll_button_2)
    |> (&%{state | graph: &1}).()
  end

  defp scroll_button_size(%{scroll_buttons: :none}), do: 0
  defp scroll_button_size(%{width: width, height: height, direction: direction}) do
    Direction.return(1, direction)
    |> Direction.invert
    |> Direction.multiply(width)
    |> Direction.multiply(height)
    |> Direction.unwrap
  end

  defp init_position_cap(%{direction: direction} = state) do
    max = Direction.return(0, direction)
          |> Direction.add(state.width)
          |> Direction.add(state.height)
          |> Direction.map_horizontal(fn width -> width - button_width(state) + scroll_button_size(state) end)
          |> Direction.map_vertical(fn height -> height - button_height(state) + scroll_button_size(state) end)
          |> Direction.to_vector_2

    min = scroll_bar_displacement(state)
          |> Direction.to_vector_2

    Map.put(state, :position_cap, PositionCap.init(%{min: min, max: max}))
  end

  defp init_graph(state) do
    width = Direction.unwrap(state.width)
    height = Direction.unwrap(state.height)

    # TODO pass as options
    drag_control_theme = Theme.preset(:light)
    bg_theme = Theme.preset(:dark)

    Map.update!(state, :graph, fn graph ->
      graph
      |> rrect(
        {width, height, @default_button_radius},
        id: :scrollbar_slider_background,
        fill: bg_theme.background,
        stroke: {@default_stroke_size, bg_theme.border},
        translate: Direction.to_vector_2(scroll_bar_displacement(state))
      )
      |> rrect(
        {button_width(state), button_height(state), @default_button_radius},
        id: :scrollbar_slider_drag_control,
        translate: local_scroll_position_vector2(state),
        fill: drag_control_theme.background
      )
      |> rect({0, 0}, id: :input_capture)
    end)
    |> init_scroll_buttons
    |> get_and_push_graph
  end

  defp button_width(%{direction: :horizontal} = state) do
    Direction.divide(state.frame_size, state.content_size)
    |> Direction.multiply(state.width)
    |> Direction.unwrap
  end
  defp button_width(state), do: Direction.unwrap(state.width)

  defp button_height(%{direction: :vertical} = state) do
    Direction.divide(state.frame_size, state.content_size)
    |> Direction.multiply(state.height)
    |> Direction.unwrap
  end
  defp button_height(state), do: Direction.unwrap(state.height)

  defp width_factor(%{content_size: {:horizontal, size}, width: {_, width}}) do
    width / size
  end

  defp width_factor(_), do: 1

  defp height_factor(%{content_size: {:vertical, size}, height: {_, height}}) do
    height / size
  end

  defp height_factor(_), do: 1

  defp scroll_position_vector2(state) do
    Direction.to_vector_2(state.scroll_position)
  end

  defp local_scroll_position_vector2(state) do
    world_to_local(state, scroll_position_vector2(state))
  end

  defp update_scroll_position(%{direction: direction} = state) do
    Drag.new_position(state.drag_state)
    |> OptionEx.map(&Direction.from_vector_2(&1, direction))
    |> OptionEx.map(&Direction.map(&1, fn position -> local_to_world(state, position) end)) 
    |> OptionEx.map(&%{state | scroll_position: &1})
    |> OptionEx.or_else(state)
  end

  defp local_to_world(%{direction: :horizontal} = state, {:horizontal, x}) do
    {:horizontal, local_to_world(state, x)}
  end

  defp local_to_world(%{direction: :vertical} = state, {:vertical, y}) do
    {:vertical, local_to_world(state, y)}
  end

  defp local_to_world(_, {:horizontal, _}), do: {:horizontal, 0}

  defp local_to_world(_, {:vertical, _}), do: {:vertical, 0}

  defp local_to_world(state, {x, y}) do
    {x, y} = PositionCap.cap(state.position_cap, {x, y})
    {local_to_world(state, x), local_to_world(state, y)}
  end

  defp local_to_world(_, 0), do: 0

  defp local_to_world(%{direction: :horizontal} = state, x),
    do: -(x - scroll_button_size(state)) / width_factor(state)

  defp local_to_world(%{direction: :vertical} = state, y),
    do: -(y - scroll_button_size(state)) / height_factor(state)

  defp world_to_local(%{direction: direction} = state, {x, y}) do
    position = Direction.from_vector_2({x, y}, direction)
               |> Direction.map(&world_to_local(state, &1))
               |> Direction.to_vector_2

    PositionCap.cap(state.position_cap, position)
  end

  defp world_to_local(%{direction: :horizontal} = state, x),
    do: -x * width_factor(state) + scroll_button_size(state)

  defp world_to_local(%{direction: :vertical} = state, y),
    do: -y * height_factor(state) + scroll_button_size(state)

end
