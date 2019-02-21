defmodule Scenic.Scrollable do
  @moduledoc """

  """

  use Scenic.Component

  import Scenic.Primitives, only: [group: 3, rect: 3]
  import Scenic.Scrollable.Components, only: [scroll_bars: 3]

  alias Scenic.Graph
  alias Scenic.ViewPort
  alias Scenic.ViewPort.Context
  alias Scenic.Math.Vector2
  alias Scenic.Scrollable.Hotkeys
  alias Scenic.Scrollable.Drag
  alias Scenic.Scrollable.ScrollBars
  alias Scenic.Scrollable.Acceleration
  alias Scenic.Scrollable.PositionCap

  @type v2 :: Scenic.Math.vector_2()

  @type rect :: %{
          x: number,
          y: number,
          width: number,
          height: number
        }

  @type style ::
          {:scroll_position, v2}
          | {:scroll_acceleration, number | v2}
          | {:scroll_speed, number | v2}
          | {:scroll_hotkeys, Hotkeys.t()}
          | {:scroll_fps, number}
          | {:scroll_counter_pressure, number | v2}
          | {:scroll_drag_settings, Drag.drag_settings()}
  # TODO bounce

  @type styles :: [style]

  @type scroll_state ::
          :scrolling
          | :dragging
          | :cooling_down
          | :idle

  @type builder :: (Graph.t() -> Graph.t())

  @type t :: %{
          graph: Graph.t(),
          frame: rect,
          content: rect,
          scroll_position: v2,
          fps: number,
          scrolling: scroll_state,
          drag_state: Drag.t(),
          scroll_bars: ScrollBars.t(),
          acceleration: Acceleration.t(),
          hotkeys: Hotkeys.t(),
          position_caps: PositionCap.t(),
          focused: boolean,
          animating: boolean
        }

  @type scrollable_settings :: %Scenic.Scrollable{
          frame: v2,
          content: v2 | rect
        }

  # TODO
  defstruct frame: {0, 0},
            content: {0, 0}

  @default_scroll_position {0, 0}

  @default_fps 30

  @impl Scenic.Component
  def verify(%{content: %{width: content_width, height: content_height, x: x, y: y}} = input)
      when is_number(x) and is_number(y) do
    verify(%{input | content: {content_width, content_height}})
  end

  def verify(
        %{
          frame: {frame_width, frame_height},
          content: {content_width, content_height},
          builder: builder
        } = input
      )
      when is_number(frame_width) and is_number(frame_height) and is_number(content_width) and
             is_number(content_height) and is_function(builder) do
    {:ok, input}
  end

  def verify(_), do: :invalid_input

  @impl Scenic.Scene
  def init(%{content: {content_width, content_height}} = input, opts) do
    init(%{input | content: %{x: 0, y: 0, width: content_width, height: content_height}}, opts)
  end

  def init(%{frame: {frame_width, frame_height}, content: content, builder: builder}, opts) do
    styles = opts[:styles] || %{}
    {frame_x, frame_y} = styles[:translate] || {0, 0}
    scroll_position = styles[:scroll_position] || @default_scroll_position

    %{
      graph: Graph.build(),
      frame: %{x: frame_x, y: frame_y, width: frame_width, height: frame_height},
      content: content,
      scroll_position: Vector2.add(scroll_position, {content.x, content.y}),
      scrolling: :idle,
      fps: styles[:fps] || @default_fps,
      animating: false,
      focused: false,
      acceleration: Acceleration.init(styles[:scroll_acceleration_settings]),
      hotkeys: Hotkeys.init(styles[:scroll_hotkeys]),
      drag_state: Drag.init(styles[:scroll_drag_settings]),
      scroll_bars: %{} # set by initialize event
    }
    |> init_position_caps
    |> init_graph(builder)
    |> ResultEx.return()
  end

  defp init_graph(state, builder) do
    state
    |> init_input_capture
    |> init_content(builder)
    |> init_scroll_bars
    |> get_and_push_graph
  end

  defp init_input_capture(%{graph: graph, frame: frame} = state) do
    graph
    |> rect({frame.width, frame.height}, translate: {frame.x, frame.y}, id: :input_capture)
    |> (&%{state | graph: &1}).()
  end

  defp init_content(%{graph: graph, frame: frame, content: content} = state, builder) do
    # MEMO: stacking up groups and scenes will result in reaching the cap prety fast when nesting scrollable elements
    group(
      graph,
      fn graph ->
        graph
        |> group(builder, id: :content, translate: Vector2.add(state.scroll_position, {content.x, content.y})) #{content.x - scroll_x, content.y - scroll_y})
      end,
      scissor: {frame.width, frame.height},
      translate: {frame.x, frame.y}
    )
    |> (&%{state | graph: &1}).()
  end

  defp init_scroll_bars(%{graph: graph} = state) do
    update_scroll_bars(graph, state)
    |> (&%{state | graph: &1}).()
  end

  defp update_scroll_bars(state) do
    # TODO refactor?
    # MEMO directly calling scroll bar for performance issues, there might be a cleaner way to do this
    state.scroll_bars.pid
    |> OptionEx.return
    |> OptionEx.map(fn pid ->
      new_scrollbar_position = Vector2.sub(state.scroll_position, {state.content.x, state.content.y})
      GenServer.call(pid, {:update_scroll_position, new_scrollbar_position})
    end)

    state
    #    graph
    #    |> Graph.modify(:scroll_bars, fn primitive -> update_scroll_bars(primitive, state) end)
    #    |> (&%{state | graph: &1}).()
  end

  defp update_scroll_bars(graph_or_primitive, %{frame: frame} = state) do
    scroll_bars(graph_or_primitive, %{
      width: frame.width,
      height: frame.height,
      content_size: {state.content.width, state.content.height},
      scroll_position: Vector2.sub(state.scroll_position, {state.content.x, state.content.y}),
    }, id: :scroll_bars)
  end

  @spec update(t) :: t
  defp update(state) do
    state
    |> update_scroll_state
    |> update_input_capture_range
    |> apply_force
    |> translate
    |> update_scroll_bars
    |> get_and_push_graph
    |> tick
  end

  @spec update_scroll_state(t) :: t
  defp update_scroll_state(state) do
    verify_idle_state(state)
    |> OptionEx.or_try(fn -> verify_dragging_state(state) end)
    |> OptionEx.or_try(fn -> verify_scrolling_state(state) end)
    |> OptionEx.or_try(fn -> verify_cooling_down_state(state) end)
    |> OptionEx.map(&%{state | scrolling: &1})
    |> OptionEx.or_else(state)
  end

  @spec apply_force(t) :: t
  defp apply_force(%{scrolling: :idle} = state), do: state

  defp apply_force(%{scrolling: :dragging} = state) do
    OptionEx.from_bool(ScrollBars.dragging?(state.scroll_bars), state.scroll_bars)
    |> OptionEx.bind(&ScrollBars.new_position/1)
    |> OptionEx.map(fn new_position -> Vector2.add(new_position, {state.content.x, state.content.y}) end)
    |> OptionEx.or_try(fn ->
      OptionEx.from_bool(Drag.dragging?(state.drag_state), state.drag_state)
      |> OptionEx.bind(&Drag.new_position/1)
    end)
    |> OptionEx.map(&%{state | scroll_position: PositionCap.cap(state.position_caps, &1)})
    |> OptionEx.or_else(state)
  end

  defp apply_force(state) do
    force =
      Hotkeys.direction(state.hotkeys)
      |> Vector2.add(ScrollBars.direction(state.scroll_bars))

    Acceleration.apply_force(state.acceleration, force)
    |> Acceleration.apply_counter_pressure()
    |> (&%{state | acceleration: &1}).()
    |> (fn state ->
          Map.update(state, :scroll_position, {0, 0}, fn scroll_pos ->
            scroll_pos = Acceleration.translate(state.acceleration, scroll_pos)
            PositionCap.cap(state.position_caps, scroll_pos)
          end)
        end).()
  end

  @spec translate(t) :: t
  defp translate(%{content: %{x: x, y: y}} = state) do
    Map.update!(state, :graph, fn graph ->
      graph
      |> Graph.modify(:content, fn primitive ->
        Map.update(primitive, :transforms, %{}, fn styles ->
          Map.put(styles, :translate, Vector2.add(state.scroll_position, {x, y}))
        end)
      end)
    end)
  end

  @spec verify_idle_state(t) :: {:some, :idle} | :none
  defp verify_idle_state(state) do
    result =
      Hotkeys.direction(state.hotkeys) == {0, 0} and not Drag.dragging?(state.drag_state) and
        (ScrollBars.direction(state.scroll_bars) == {0, 0}) and
        not ScrollBars.dragging?(state.scroll_bars) and
        Acceleration.is_stationary?(state.acceleration)

    OptionEx.from_bool(result, :idle)
  end

  @spec verify_dragging_state(t) :: {:some, :dragging} | :none
  defp verify_dragging_state(state) do
    result = Drag.dragging?(state.drag_state) or ScrollBars.dragging?(state.scroll_bars)

    OptionEx.from_bool(result, :dragging)
  end

  @spec verify_scrolling_state(t) :: {:some, :scrolling} | :none
  defp verify_scrolling_state(state) do
    result =
      Hotkeys.direction(state.hotkeys) != {0, 0} or
        (ScrollBars.direction(state.scroll_bars) != {0, 0} and not (state.scrolling == :dragging))

    OptionEx.from_bool(result, :scrolling)
  end

  @spec verify_cooling_down_state(t) :: {:some, :cooling_down} | :none
  defp verify_cooling_down_state(state) do
    result =
      Hotkeys.direction(state.hotkeys) == {0, 0} and not Drag.dragging?(state.drag_state) and
        (ScrollBars.direction(state.scroll_bars) == {0, 0}) and
        not ScrollBars.dragging?(state.scroll_bars) and
        not Acceleration.is_stationary?(state.acceleration)

    OptionEx.from_bool(result, :cooling_down)
  end

  @impl Scenic.Scene
  def handle_input(
        {:cursor_button, {:left, :press, _, {x, y}}},
        context,
        state
      ) do
    state
    |> capture_focus(context)
    |> Map.update!(
      :drag_state,
      &Drag.handle_mouse_click(&1, :left, {x, y}, state.scroll_position)
    )
    |> update
    |> (&{:noreply, &1}).()
  end

  def handle_input({:cursor_button, {button, :press, _, cursor_pos}}, _, state) do
    state
    |> Map.update!(
      :drag_state,
      &Drag.handle_mouse_click(&1, button, cursor_pos, state.scroll_position)
    )
    |> update
    |> (&{:noreply, &1}).()
  end

  def handle_input({:cursor_pos, cursor_pos}, _, state) do
    state
    |> Map.update!(:drag_state, &Drag.handle_mouse_move(&1, cursor_pos))
    |> update
    |> (&{:noreply, &1}).()
  end

  def handle_input({:cursor_button, {:left, :release, _, cursor_pos}}, _, state) do
    state
    |> start_cooling_down(cursor_pos)
    |> Map.update!(:drag_state, &Drag.handle_mouse_release(&1, :left, cursor_pos))
    |> update
    |> (&{:noreply, &1}).()
  end

  def handle_input({:cursor_button, {button, :release, _, cursor_pos}}, _, state) do
    state
    |> Map.update!(:drag_state, &Drag.handle_mouse_release(&1, button, cursor_pos))
    |> start_cooling_down(cursor_pos)
    |> update
    |> (&{:noreply, &1}).()
  end

  def handle_input({:key, {"escape", :release, _}}, context, state) do
    release_focus(state, context)
    {:noreply, state}
  end

  def handle_input(
        {:key, {key, :press, _}},
        _,
        state
      ) do
    Map.update!(state, :hotkeys, &Hotkeys.handle_key_press(&1, key))
    |> update
    |> (&{:noreply, &1}).()
  end

  def handle_input(
        {:key, {key, :release, _}},
        _,
        state
      ) do
    Map.update!(state, :hotkeys, &Hotkeys.handle_key_release(&1, key))
    |> update
    |> (&{:noreply, &1}).()
  end

  def handle_input(_input, _, state) do
    {:noreply, state}
  end

  @impl(Scenic.Scene)
  def filter_event({:scroll_bars_initialized, _id, scroll_bars_state}, _from, state) do
    %{state | scroll_bars: scroll_bars_state}
    |> (&{:stop, &1}).()
  end

  def filter_event({:scroll_bars_position_change, _id, scroll_bars_state}, _from, state) do
    %{state | scroll_bars: scroll_bars_state}
    |> update
    |> (&{:stop, &1}).()
  end

  def filter_event({:scroll_bars_scroll_end, _id, scroll_bars_state}, _from, state) do
    %{state | scroll_bars: scroll_bars_state}
    |> update
    |> (&{:stop, &1}).()
  end

  def filter_event(event, _, state) do
    {:continue, event, state}
  end

  # no callback on the `Scenic.Scene` and no GenServer @behaviour, so impl will not work
  def handle_info(:tick, state) do
    %{state | animating: false}
    |> update
    |> (&{:noreply, &1}).()
  end

  @spec start_cooling_down(t, v2) :: t
  defp start_cooling_down(state, cursor_pos) do
    speed =
      Drag.last_position(state.drag_state)
      |> OptionEx.or_else(cursor_pos)
      |> (&Vector2.sub(cursor_pos, &1)).()
      |> (&Drag.amplify_speed(state.drag_state, &1)).()

    Map.update!(state, :acceleration, &Acceleration.set_speed(&1, speed))
  end

  @spec capture_focus(t, Context.t) :: t
  defp capture_focus(%{focused: false} = state, context) do
    ViewPort.capture_input(context, :key)

    %{state | focused: true}
  end

  defp capture_focus(state, _), do: state

  @spec release_focus(t, Context.t) :: t
  defp release_focus(%{focused: true} = state, context) do
    ViewPort.release_input(context, :key)

    %{state | focused: false}
  end

  defp release_focus(state, _), do: state

  @spec update_input_capture_range(t) :: t
  defp update_input_capture_range(%{graph: _, scrolling: :dragging} = state) do
    Map.update!(state, :graph, fn graph ->
      graph
      # TODO get screen res (for all monitors added up) somehow ?
      |> Graph.modify(:input_capture, fn primitive ->
        rect(primitive, {4000, 3000}, translate: {-2000, -1500}, id: :input_capture)
      end)
    end)
  end

  defp update_input_capture_range(%{graph: _, frame: frame} = state) do
    Map.update!(state, :graph, fn graph ->
      graph
      |> Graph.modify(:input_capture, fn primitive ->
        rect(primitive, {frame.width, frame.height},
          translate: {frame.x, frame.y},
          id: :input_capture
        )
      end)
    end)
  end

  @spec tick(t) :: t
  defp tick(%{scrolling: :idle} = state), do: %{state | animating: false}

  defp tick(%{scrolling: :dragging} = state), do: %{state | animating: false}

  defp tick(%{animating: true} = state), do: state

  defp tick(state) do
    Process.send_after(self(), :tick, tick_time(state))
    %{state | animating: true}
  end

  @spec tick_time(t) :: number
  defp tick_time(%{fps: fps}) do
    trunc(1000 / fps)
  end

  @spec get_and_push_graph(t) :: t
  defp get_and_push_graph(%{graph: graph} = state) do
    push_graph(graph)
    state
  end

  defp init_position_caps(%{
    frame: %{width: frame_width, height: frame_height},
    content: %{x: x, y: y, width: content_width, height: content_height}
  } = state) do
    min = {x + frame_width - content_width, y + frame_height - content_height}
    max = {x, y}

    Map.put(state, :position_caps, PositionCap.init(%{min: min, max: max}))
  end
end
