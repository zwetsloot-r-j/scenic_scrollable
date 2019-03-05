defmodule Scenic.Scrollable.ScrollBar do
  use Scenic.Component

  import Scenic.Primitives, only: [rrect: 3, rect: 3, text: 3]

  alias Scenic.Graph
  alias Scenic.Primitive
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

  @type mouse_button :: :left
  | :right
  | :middle

  @type style :: {:scroll_buttons, boolean} # TODO enable images as buttons
  | {:scrollbar_theme, %{}} # TODO use Scenic.Theme.t when/if it gets defined
  | {:scrollbar_mouse_buttons_enabled, [mouse_button]}
  | {:scrollbar_radius, number}
  | {:scrollbar_border, number}

  @type styles :: [style]

  @type t :: %{
    id: atom,
    graph: Graph.t,
    width: Direction.t,
    height: Direction.t,
    frame_size: Direction.t,
    content_size: Direction.t,
    scroll_position: Direction.t,
    last_scroll_position: Direction.t,
    direction: scroll_direction,
    drag_state: Drag.t,
    position_cap: PositionCap.t,
    scroll_buttons: {:some, %{
      scroll_button_1: :pressed | :released,
      scroll_button_2: :pressed | :released
    }} | :none,
    scrollbar_slider_background: :pressed | :released,
    scroll_state: :idle | :scrolling | :dragging,
    pid: pid
  }

  defstruct id: :scroll_bar,
    graph: nil,
    width: nil,
    height: nil,
    content_size: nil,
    frame_size: nil,
    scroll_position: nil,
    last_scroll_position: nil,
    direction: nil,
    drag_state: %{},
    position_cap: %{},
    scroll_buttons: :none,
    scrollbar_slider_background: :released,
    scroll_state: :idle,
    pid: nil

  @default_drag_settings [:left, :right, :middle]
  @default_button_radius 3
  @default_stroke_size 1
  @default_id :scroll_bar

  def init(%{width: width, height: height, content_size: content_size, direction: direction} = settings, opts) do
    styles = opts[:styles] || %{}
    scroll_buttons = styles[:scroll_buttons] || false

    %__MODULE__{
      id: opts[:id] || @default_id,
      graph: Graph.build(),
      content_size: Direction.return(content_size, direction),
      frame_size: Direction.from_vector_2({width, height}, direction),
      scroll_position: Direction.return(settings.scroll_position, direction),
      last_scroll_position: Direction.return(settings.scroll_position, direction),
      direction: direction,
      drag_state: Drag.init(styles[:scroll_drag_settings] || @default_drag_settings),
      scroll_buttons: OptionEx.from_bool(scroll_buttons, %{
        scroll_button_1: :released,
        scroll_button_2: :released
      }),
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

  def direction(pid) when is_pid(pid) do
    GenServer.call(pid, :direction)
  end

  def direction(%{scroll_buttons: {:some, %{scroll_button_1: :pressed, scroll_button_2: :released}}, direction: direction}) do
    Direction.return(1, direction)
    |> Direction.to_vector_2
  end

  def direction(%{scroll_buttons: {:some, %{scroll_button_1: :released, scroll_button_2: :pressed}}, direction: direction}) do
    Direction.return(-1, direction)
    |> Direction.to_vector_2
  end

  def direction(_), do: {0, 0}

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
    |> update
    |> get_and_push_graph
    |> (&{:noreply, &1}).()
  end

  def handle_input({:cursor_pos, position}, %{id: :input_capture}, state) do
    state
    |> Map.update!(:drag_state, fn drag_state ->
      Drag.handle_mouse_move(drag_state, position)
    end)
    |> update
    |> (&{:noreply, &1}).()
  end

  def handle_input({:cursor_button, {_button, :release, _, _}}, %{id: :scroll_button_1}, state) do
    state = Map.update!(state, :scroll_buttons, fn scroll_buttons ->
      OptionEx.map(scroll_buttons, &%{&1 | scroll_button_1: :released})
    end)
    |> update

    :ok = send_event({:scroll_bar_button_released, state.id, state})

    {:noreply, state}
  end

  def handle_input({:cursor_button, {_button, :release, _, _}}, %{id: :scroll_button_2}, state) do
    state = Map.update!(state, :scroll_buttons, fn scroll_buttons ->
      OptionEx.map(scroll_buttons, &%{&1 | scroll_button_2: :released})
    end)
    |> update

    :ok = send_event({:scroll_bar_button_released, state.id, state})

    {:noreply, state}
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
    |> (&{:noreply, &1}).()
  end

  def handle_input({:cursor_button, {_button, :press, _, _}}, %{id: :scroll_button_1}, state) do
    state = Map.update!(state, :scroll_buttons, fn scroll_buttons ->
      OptionEx.map(scroll_buttons, &%{&1 | scroll_button_1: :pressed})
    end)
    |> update

    :ok = send_event({:scroll_bar_button_pressed, state.id, state})

    {:noreply, state}
  end

  def handle_input({:cursor_button, {_button, :press, _, _}}, %{id: :scroll_button_2}, state) do
    state = Map.update!(state, :scroll_buttons, fn scroll_buttons ->
      OptionEx.map(scroll_buttons, &%{&1 | scroll_button_2: :pressed})
    end)
    |> update

    :ok = send_event({:scroll_bar_button_pressed, state.id, state})

    {:noreply, state}
  end

  def handle_input({:cursor_button, {_button, :press, _, position}}, _, %{direction: direction} = state) do
    %{state | scrollbar_slider_background: :pressed}
    |> update
    |> (&{:noreply, &1}).()
  end

  def handle_input({:cursor_button, {_button, :release, _, position}}, _, %{direction: direction} = state) do
    scroll_position = Direction.from_vector_2(position, direction)
                      |> Direction.map_horizontal(fn pos -> pos - button_width(state) / 2 end)
                      |> Direction.map_vertical(fn pos -> pos - button_height(state) / 2 end)

    scroll_position = local_to_world(state, scroll_position)

    state
    |> Map.put(:scrollbar_slider_background, :released)
    |> Map.put(:last_scroll_position, state.scroll_position)
    |> Map.put(:scroll_position, scroll_position)
    |> update
    |> (&{:noreply, &1}).()
  end

  def handle_input({:cursor_exit, _}, _, state) do
    Map.update!(state, :scroll_buttons, fn scroll_buttons ->
      OptionEx.map(scroll_buttons, &%{&1 | scroll_button_2: :released, scroll_button_1: :released})
    end)
    |> update
    |> (&{:noreply, &1}).()
  end

  def handle_input(_event, _, state) do
    {:noreply, state}
  end

  def handle_call({:update_scroll_position, position}, _, state) do
    state
    |> Map.put(:last_scroll_position, state.scroll_position)
    |> Map.put(:scroll_position, Direction.return(position, state.direction))
    |> update_graph_drag_control_position
    |> get_and_push_graph
    |> (&{:reply, :ok, &1}).()
  end

  def handle_call(:direction, _, state) do
    {:reply, direction(state), state}
  end

  def filter_event(_, _, state), do: {:stop, state}

  defp update(state) do
    state
    |> update_scroll_state
    |> update_scroll_position
    |> update_graph_drag_control_position
    |> update_control_colors
    |> get_and_push_graph
    |> send_position_change_event
  end

  defp update_scroll_state(state) do
    verify_scrolling(state)
    |> OptionEx.or_try(fn -> verify_dragging(state) end)
    |> OptionEx.or_else(:idle)
    |> (&%{state | scroll_state: &1}).()
  end

  defp verify_scrolling(%{scroll_buttons: {:some, buttons}}) do
    OptionEx.from_bool(buttons.scroll_button_1 == :pressed, :scrolling)
    |> OptionEx.or_try(fn -> OptionEx.from_bool(buttons.scroll_button_2 == :pressed, :scrolling) end)
  end

  defp verify_scrolling(_), do: :none

  defp verify_dragging(state) do
    OptionEx.from_bool(Drag.dragging?(state.drag_state), :dragging)
  end

  # MEMO: scrolling using directional buttons will only set the direction, the position of the scroll controls will be updated by the :update_scroll_position call called back by the scrollable component
  defp send_position_change_event(%{scroll_state: :scrolling} = state), do: state

  defp send_position_change_event(%{last_scroll_position: last, scroll_position: current} = state) do
    OptionEx.from_bool(last != current, state)
    |> OptionEx.map(fn state ->
      :ok = send_event({:scroll_bar_position_change, state.id, state})
      state
    end).()
    |> OptionEx.or_else(state)
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

  def update_control_colors(state) do
    # TODO pass as options
    drag_control_theme = Theme.preset(:light)
    bg_theme = Theme.preset(:dark)

    drag_control_color = Drag.dragging?(state.drag_state)
                         |> OptionEx.from_bool(drag_control_theme.active)
                         |> OptionEx.or_else(drag_control_theme.background)

    scrollbar_slider_background_color = OptionEx.from_bool(state.scrollbar_slider_background == :pressed, bg_theme.active)
                                        |> OptionEx.or_else(bg_theme.background)

    graph = state.graph
            |> Graph.modify(:scrollbar_slider_drag_control, &Primitive.put_style(&1, :fill, drag_control_color))
            |> Graph.modify(:scrollbar_slider_background, &Primitive.put_style(&1, :fill, scrollbar_slider_background_color))

    graph = state.scroll_buttons
            |> OptionEx.map(fn scroll_buttons ->
              button1_color = OptionEx.from_bool(scroll_buttons.scroll_button_1 == :pressed, drag_control_theme.active)
                              |> OptionEx.or_else(drag_control_theme.background)

              button2_color = OptionEx.from_bool(scroll_buttons.scroll_button_2 == :pressed, drag_control_theme.active)
                              |> OptionEx.or_else(drag_control_theme.background)

              graph
              |> Graph.modify(:scroll_button_1, &Primitive.put_style(&1, :fill, button1_color))
              |> Graph.modify(:scroll_button_2, &Primitive.put_style(&1, :fill, button2_color))
            end)
            |> OptionEx.or_else(graph)

    Map.put(state, :graph, graph)
  end

  defp init_scroll_buttons(%{scroll_buttons: :none} = state), do: state
  defp init_scroll_buttons(%{graph: graph, direction: direction} = state) do
    # TODO pass as options
    theme = Theme.preset(:light)

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
    |> rrect(
      {size, size, @default_button_radius},
      id: :scroll_button_1,
      translate: {0, 0},
      fill: theme.background
    )
    |> text(
      btn1_text,
      font_size: 15,
      fill: :black,
      translate: {size * 0.5, size * 1},
      text_align: :center
    )
    |> rrect(
      {size, size, @default_button_radius},
      id: :scroll_button_2,
      translate: button_2_position,
      fill: theme.background
    )
    |> text(
      btn2_text,
      font_size: 15,
      fill: :black,
      translate: Vector2.add(button_2_position, {size * 0.5, size * 1}),
      text_align: :center
    )
    |> (&%{state | graph: &1}).()
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
    |> OptionEx.map(&%{state | last_scroll_position: state.scroll_position, scroll_position: &1})
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
    {local_to_world(state, x), local_to_world(state, y)}
  end

  defp local_to_world(_, 0), do: 0

  defp local_to_world(%{direction: :horizontal} = state, x) do
    {x, _} = PositionCap.cap(state.position_cap, {x, 0})
    -(x - scroll_button_size(state)) / width_factor(state)
  end

  defp local_to_world(%{direction: :vertical} = state, y) do
    {_, y} = PositionCap.cap(state.position_cap, {0, y})
    -(y - scroll_button_size(state)) / height_factor(state)
  end

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
