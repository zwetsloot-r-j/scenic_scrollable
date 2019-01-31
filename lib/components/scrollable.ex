defmodule Scenic.Scrollable do
  use Scenic.Component

  import Scenic.Primitives, only: [group: 3, rect: 3]

  alias Scenic.Graph
  alias Scenic.ViewPort
  alias Scenic.Math.Vector2
  alias Scenic.Scrollable.Hotkeys
  alias Scenic.Scrollable.Drag
  alias Scenic.Scrollable.ScrollBar
  alias Scenic.Scrollable.Acceleration

  @type vector2 :: Scenic.Math.vector_2()

  @type rect :: %{
          x: number,
          y: number,
          width: number,
          height: number
        }

  @type style ::
          {:scroll_position, vector2}
          | {:scroll_acceleration, number | vector2}
          | {:scroll_speed, number | vector2}
          | {:scroll_hotkeys, Hotkeys.t()}
          | {:scroll_fps, number}
          | {:scroll_counter_pressure, number | vector2}
          | {:scroll_drag_settings, Drag.drag_settings()}
  # TODO bounce

  @type styles :: [style]

  @type scroll_state ::
          :scrolling
          | :dragging
          | :cooling_down
          | :idle

  @type builder :: (Graph.t() -> Graph.t())

  @type state :: %{
          graph: Graph.t(),
          frame: rect,
          content: rect,
          scroll_position: vector2,
          fps: number,
          scrolling: scroll_state,
          drag_state: Drag.t(),
          scrollbar: ScrollBar.t(),
          acceleration: Acceleration.t(),
          hotkeys: Hotkeys.t(),
          focused: boolean,
          animating: boolean
        }

  @type t :: %Scenic.Scrollable{
          frame: vector2,
          content: vector2 | rect
        }

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
    {scroll_x, scroll_y} = styles[:scroll_position] || @default_scroll_position

    graph =
      Graph.build()
      |> rect({frame_width, frame_height}, translate: {frame_x, frame_y}, id: :input_capture)
      # MEMO: stacking up groups and scenes will result in reaching the cap prety fast when nesting scrollable elements
      |> group(
        fn graph ->
          graph
          |> group(builder, id: :content, translate: {content.x - scroll_x, content.y - scroll_y})
        end,
        scissor: {frame_width, frame_height},
        translate: {frame_x, frame_y}
      )
      |> push_graph

    %{
      graph: graph,
      frame: %{x: frame_x, y: frame_y, width: frame_width, height: frame_height},
      content: content,
      scroll_position: {scroll_x, scroll_y},
      fps: styles[:fps] || @default_fps,
      animating: false,
      scrolling: :idle,
      acceleration: Acceleration.init(styles[:scroll_acceleration_settings]),
      hotkeys: Hotkeys.init(styles[:scroll_hotkeys]),
      drag_state: Drag.init(styles[:scroll_drag_settings]),
      scrollbar: ScrollBar.init(:todo),
      focused: false
    }
    |> ResultEx.return()
  end

  defp update(state) do
    state
    |> update_scroll_state
    |> update_input_capture_range
    |> apply_force
    |> translate
    |> get_and_push_graph
    |> tick
  end

  defp update_scroll_state(state) do
    verify_idle_state(state)
    |> OptionEx.or_try(fn -> verify_dragging_state(state) end)
    |> OptionEx.or_try(fn -> verify_scrolling_state(state) end)
    |> OptionEx.or_try(fn -> verify_cooling_down_state(state) end)
    |> OptionEx.map(&%{state | scrolling: &1})
    |> OptionEx.or_else(state)
  end

  defp apply_force(%{scrolling: :idle} = state), do: state

  defp apply_force(%{scrolling: :dragging} = state) do
    OptionEx.from_bool(Drag.dragging?(state.drag_state), {Drag, state.drag_state})
    |> OptionEx.or_try(fn ->
      OptionEx.from_bool(ScrollBar.dragging?(state.scrollbar), {ScrollBar, state.scrollbar})
    end)
    |> OptionEx.bind(fn {mod, state} -> mod.new_position(state) end)
    |> OptionEx.map(&%{state | scroll_position: cap(state, &1)})
    |> OptionEx.or_else(state)
  end

  defp apply_force(state) do
    force =
      Hotkeys.direction(state.hotkeys)
      |> Vector2.add(ScrollBar.direction(state.scrollbar))

    Acceleration.apply_force(state.acceleration, force)
    |> Acceleration.apply_counter_pressure()
    |> (&%{state | acceleration: &1}).()
    |> (fn state ->
          Map.update(state, :scroll_position, {0, 0}, fn scroll_pos ->
            scroll_pos = Acceleration.translate(state.acceleration, scroll_pos)
            cap(state, scroll_pos)
          end)
        end).()
  end

  defp translate(state) do
    Map.update!(state, :graph, fn graph ->
      graph
      |> Graph.modify(:content, fn primitive ->
        Map.update(primitive, :transforms, %{}, fn styles ->
          Map.put(styles, :translate, state.scroll_position)
        end)
      end)
    end)
  end

  defp verify_idle_state(state) do
    result =
      Hotkeys.direction(state.hotkeys) == {0, 0} and not Drag.dragging?(state.drag_state) and
        not (ScrollBar.direction(state.scrollbar) == {0, 0}) and
        not ScrollBar.dragging?(state.scrollbar) and
        Acceleration.is_stationary?(state.acceleration)

    OptionEx.from_bool(result, :idle)
  end

  defp verify_dragging_state(state) do
    result = Drag.dragging?(state.drag_state) or ScrollBar.dragging?(state.scrollbar)

    OptionEx.from_bool(result, :dragging)
  end

  defp verify_scrolling_state(state) do
    result =
      Hotkeys.direction(state.hotkeys) != {0, 0} or
        (ScrollBar.direction(state.scrollbar) != {0, 0} and not (state.scrolling == :dragging))

    OptionEx.from_bool(result, :scrolling)
  end

  defp verify_cooling_down_state(state) do
    result =
      Hotkeys.direction(state.hotkeys) == {0, 0} and not Drag.dragging?(state.drag_state) and
        not (ScrollBar.direction(state.scrollbar) == {0, 0}) and
        not ScrollBar.dragging?(state.scrollbar) and
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
    |> Map.update!(:drag_state, &Drag.handle_mouse_release(&1, :left, cursor_pos))
    |> start_cooling_down(cursor_pos)
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

  def handle_info(:tick, state) do
    %{state | animating: false}
    |> update
    |> (&{:noreply, &1}).()
  end

  defp start_cooling_down(state, cursor_pos) do
    speed =
      Drag.last_position(state.drag_state)
      |> OptionEx.or_try(fn -> ScrollBar.last_position(state.scrollbar) end)
      |> OptionEx.or_else(cursor_pos)
      |> (&Vector2.sub(cursor_pos, &1)).()

    Map.update!(state, :acceleration, &Acceleration.set_speed(&1, speed))
  end

  defp capture_focus(%{focused: false} = state, context) do
    ViewPort.capture_input(context, :key)

    %{state | focused: true}
  end

  defp capture_focus(state, _), do: state

  defp release_focus(%{focused: true} = state, context) do
    ViewPort.release_input(context, :key)

    %{state | focused: false}
  end

  defp release_focus(state, _), do: state

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

  defp tick(%{scrolling: :idle} = state), do: %{state | animating: false}

  defp tick(%{scrolling: :dragging} = state), do: %{state | animating: false}

  defp tick(%{animating: true} = state), do: state

  defp tick(state) do
    Process.send_after(self(), :tick, tick_time(state))
    %{state | animating: true}
  end

  defp tick_time(%{fps: fps}) do
    trunc(1000 / fps)
  end

  defp get_and_push_graph(%{graph: graph} = state) do
    push_graph(graph)
    state
  end

  defp max_x(%{content: %{x: x}}), do: x

  defp min_x(%{frame: %{width: frame_width}, content: %{x: x, width: content_width}}) do
    x + frame_width - content_width
  end

  defp max_y(%{content: %{y: y}}), do: y

  defp min_y(%{frame: %{height: frame_height}, content: %{y: y, height: content_height}}) do
    y + frame_height - content_height
  end

  defp cap(state, {x, y}) do
    {cap_x(state, x), cap_y(state, y)}
  end

  defp cap_x(_, 0.0), do: 0
  defp cap_x(_, 0), do: 0

  defp cap_x(state, x) when x < 0 do
    max(min_x(state), x)
  end

  defp cap_x(state, x) when x > 0 do
    min(max_x(state), x)
  end

  defp cap_y(_, 0.0), do: 0
  defp cap_y(_, 0), do: 0

  defp cap_y(state, y) when y < 0 do
    max(min_y(state), y)
  end

  defp cap_y(state, y) when y > 0 do
    min(max_y(state), y)
  end
end
