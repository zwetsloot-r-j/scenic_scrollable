defmodule Scenic.Scrollable.ScrollBar do
  use Scenic.Component, has_children: false

  import Scenic.Primitives, only: [rrect: 3, rect: 3]

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
    content_size: Direction.t,
    scroll_position: Direction.t,
    direction: scroll_direction,
    drag_state: Drag.t,
    drag_button_clicked: boolean,
    position_cap: PositionCap.t
  }

  @default_drag_settings [:left, :right, :middle]
  @default_button_radius 3
  @default_stroke_size 1
  @default_id :scroll_bar

  def init(%{width: width, height: height, content_size: content_size, direction: direction} = settings, opts) do
    styles = opts[:styles] || %{}

    %{
      id: opts[:id] || @default_id,
      graph: Graph.build(),
      width: Direction.as_horizontal(width),
      height: Direction.as_vertical(height),
      content_size: Direction.return(content_size, direction),
      scroll_position: Direction.return(settings.scroll_position, direction),
      direction: direction,
      drag_state: Drag.init(styles[:scroll_drag_settings] || @default_drag_settings),
      drag_button_clicked: false,
      pid: self()
    }
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

  def handle_input({:cursor_button, {_button, :press, _, position}}, _, state) do
    scroll_position = vector2_to_direction(state, position)
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

  defp init_position_cap(%{width: {_, width}, height: {_, height}, direction: direction} = state) do
    max_x = Direction.map_horizontal({direction, width}, fn width -> width - button_width(state) end)
            |> Direction.map_vertical(fn _ -> 0 end)
            |> Direction.unwrap

    max_y = Direction.map_vertical({direction, height}, fn height -> height - button_height(state) end)
            |> Direction.map_horizontal(fn _ -> 0 end)
            |> Direction.unwrap

    Map.put(state, :position_cap, PositionCap.init(%{min: {0, 0}, max: {max_x, max_y}}))
  end

  defp init_graph(state) do
    width = Direction.unwrap(state.width)
    height = Direction.unwrap(state.height)

    drag_control_theme = Theme.preset(:light)
    bg_theme = Theme.preset(:dark)

    Map.update!(state, :graph, fn graph ->
      graph
      |> rrect(
        {width, height, @default_button_radius},
        id: :scrollbar_slider_background,
        fill: bg_theme.background,
        stroke: {@default_stroke_size, bg_theme.border}
      )
      |> rrect(
        {button_width(state), button_height(state), @default_button_radius},
        id: :scrollbar_slider_drag_control,
        translate: local_scroll_position_vector2(state),
        fill: drag_control_theme.background
      )
      |> rect({0, 0}, id: :input_capture)
      |> push_graph
    end)
    # TODO add optional directional buttons
  end

  defp button_width(state) do
    Direction.unwrap(state.width) * width_factor(state)
  end

  defp button_height(state) do
    Direction.unwrap(state.height) * height_factor(state)
  end

  defp width_factor(%{content_size: size, width: {_, width}}) do
    Direction.map_horizontal(size, fn size -> width / size end)
    |> Direction.map_vertical(fn _ -> 1 end)
    |> Direction.unwrap
  end

  defp height_factor(%{content_size: size, height: {_, height}}) do
    Direction.map_vertical(size, fn size -> height / size end)
    |> Direction.map_horizontal(fn _ -> 1 end)
    |> Direction.unwrap
  end

  defp scroll_position_vector2(state) do
    x = Direction.as_horizontal(0)
        |> Direction.add(state.scroll_position)
        |> Direction.unwrap

    y = Direction.as_vertical(0)
        |> Direction.add(state.scroll_position)
        |> Direction.unwrap

    {x, y}
  end

  defp local_scroll_position_vector2(state) do
    world_to_local(state, scroll_position_vector2(state))
  end

  defp update_scroll_position(state) do
    Drag.new_position(state.drag_state)
    |> OptionEx.map(&vector2_to_direction(state, &1))
    |> OptionEx.map(&Direction.map(&1, fn position -> local_to_world(state, position) end)) 
    |> OptionEx.map(&%{state | scroll_position: &1})
    |> OptionEx.or_else(state)
  end

  defp local_to_world(%{direction: :horizontal} = state, {:horizontal, x}) do
    {:horizontal, -x / width_factor(state)}
  end

  defp local_to_world(%{direction: :vertical} = state, {:vertical, y}) do
    {:vertical, -y / height_factor(state)}
  end

  defp local_to_world(_, {:horizontal, _}), do: {:horizontal, 0}

  defp local_to_world(_, {:vertical, _}), do: {:vertical, 0}

  defp local_to_world(state, {x, y}) do
    {x, y} = PositionCap.cap(state.position_cap, {x, y})
    {local_to_world(state, x), local_to_world(state, y)}
  end

  defp local_to_world(_, 0), do: 0

  defp local_to_world(%{direction: :horizontal} = state, x), do: -x / width_factor(state)

  defp local_to_world(%{direction: :vertical} = state, y), do: -y / height_factor(state)

  defp world_to_local(state, {x, y}) do
    PositionCap.cap(state.position_cap, {-x * width_factor(state), -y * height_factor(state)})
  end

  defp world_to_local(%{direction: :horizontal} = state, x), do: -x * width_factor(state)

  defp world_to_local(%{direction: :vertical} = state, y), do: -y * height_factor(state)

  defp vector2_to_direction(%{direction: :horizontal}, {x, _}), do: {:horizontal, x}

  defp vector2_to_direction(%{direction: :vertical}, {_, y}), do: {:vertical, y}

end
