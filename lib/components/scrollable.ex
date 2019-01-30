defmodule Scenic.Scrollable do
  use Scenic.Component

  import Scenic.Primitives, only: [group: 3, rect: 3]

  alias Scenic.Graph

  # {x, y}
  @type vector2 :: {number, number}

  @type rect :: %{
          x: number,
          y: number,
          width: number,
          height: number
        }

  @type hotkeys :: %{
          up: :none | {:some, number},
          down: :none | {:some, number},
          left: :none | {:some, number},
          right: :none | {:some, number}
        }

  @type style ::
          {:scroll_position, vector2}
          | {:scroll_acceleration, number | vector2}
          | {:scroll_speed, number | vector2}
          | {:scroll_hotkeys, hotkeys}
          | {:scroll_fps, number}
          | {:scroll_counter_pressure, number | vector2}
  # TODO bounce

  @type styles :: [style]

  @type scroll_state ::
          :scrolling
          | :cooling_down
          | :idle

  @type drag_state :: %{
          starting_point: :none | {:some, vector2},
          last_point: :none | {:some, vector2},
          original_content_position: vector2
        }

  @type acceleration_state :: %{
          acceleration: vector2,
          current_speed: vector2,
          max_speed: vector2,
          counter_pressure: vector2
        }

  @type builder :: (Graph.t() -> Graph.t())

  @type state :: %{
          graph: Graph.t(),
          frame: rect,
          content: rect,
          scroll_position: vector2,
          fps: number,
          scrolling: scroll_state,
          drag_state: drag_state,
          acceleration_state: acceleration_state,
          hotkeys: hotkeys
        }

  @type t :: %Scenic.Scrollable{
          frame: vector2,
          content: vector2 | rect
        }

  defstruct frame: {0, 0},
            content: {0, 0}

  @default_acceleration {1, 1}

  @default_scroll_speed {5, 5}

  @default_scroll_position {0, 0}

  @default_fps 30

  @default_counter_pressure {2, 2}

  @default_hotkeys %{
    up: :none,
    down: :none,
    left: :none,
    right: :none
  }

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
      scrolling: false,
      acceleration_state: %{
        acceleration: parse_scroll_acceleration(styles[:scroll_acceleration]),
        current_speed: {0, 0},
        max_speed: parse_scroll_speed(styles[:scroll_speed]),
        counter_pressure: parse_scroll_counter_pressure(styles[:counter_pressure])
      },
      hotkeys: styles[:hotkeys] || @default_hotkeys
    }
    |> reset_drag_state
    |> ResultEx.return()
  end

  @impl Scenic.Scene
  def handle_input(
        {:cursor_button, {:left, :press, _, {x, y}}},
        _,
        %{graph: _, drag_state: _} = state
      ) do
    state
    |> expand_input_capture_range
    |> update_drag_state({x, y})
    |> get_and_push_graph
    |> (&{:noreply, &1}).()
  end

  def handle_input({:cursor_pos, {x, y}}, _, %{drag_state: %{starting_point: {:some, _}}} = state) do
    state
    |> update_drag_state({x, y})
    |> calculate_drag_offset({x, y})
    |> translate_content
    |> get_and_push_graph
    |> (&{:noreply, &1}).()
  end

  def handle_input({:cursor_button, {:left, :release, _, _}}, _, %{scroll_state: :idle} = state),
    do: state

  def handle_input(
        {:cursor_button, {:left, :release, _, _}},
        _,
        %{scroll_state: :cooling_down} = state
      ),
      do: state

  def handle_input({:cursor_button, {:left, :release, _, {x, y}}}, _, state) do
    state
    |> Map.put(:scrolling, :cooling_down)
    |> calculate_force({x, y})
    |> reset_drag_state
    |> collapse_input_capture_range
    |> get_and_push_graph
    |> tick
    |> (&{:noreply, &1}).()
  end

  def handle_input(input, _, state) do
    # IO.inspect(input, label: "input")
    {:noreply, state}
  end

  # MEMO: no callback declared in Scenic.Scene, and no Genserver behaviour declared either, so @impl will fail
  # @impl(Scenic.Scene)
  @doc false
  def handle_info(:tick, %{scrolling: :idle} = state) do
    {:noreply, state}
  end

  def handle_info(
        :tick,
        %{scrolling: :cooling_down, acceleration_state: %{current_speed: {0, 0}}} = state
      ) do
    %{state | scrolling: :idle}
    |> (&{:noreply, &1}).()
  end

  def handle_info(
        :tick,
        %{
          scrolling: :scrolling,
          acceleration_state: %{current_speed: {0, 0}},
          drag_state: %{starting_point: :none}
        } = state
      ) do
    tick(state)
    |> (&{:noreply, &1}).()
  end

  def handle_info(:tick, %{acceleration_state: %{current_speed: {v_x, v_y}}} = state) do
    state
    |> Map.update(:scroll_position, {0, 0}, fn {x, y} -> cap(state, {x + v_x, y + v_y}) end)
    |> apply_counter_pressure
    |> translate_content
    |> get_and_push_graph
    |> tick
    |> (&{:noreply, &1}).()
  end

  defp translate_content(state) do
    Map.update!(state, :graph, fn graph ->
      graph
      |> Graph.modify(:content, fn primitive ->
        Map.update(primitive, :transforms, %{}, fn styles ->
          Map.put(styles, :translate, state.scroll_position)
        end)
      end)
    end)
  end

  defp expand_input_capture_range(%{scrolling: :scrolling} = state), do: state
  defp expand_input_capture_range(%{scrolling: :cooling_down} = state), do: state

  defp expand_input_capture_range(%{graph: _} = state) do
    Map.update!(state, :graph, fn graph ->
      graph
      # TODO get screen res (for all monitors added up) somehow ?
      |> Graph.modify(:input_capture, fn primitive ->
        rect(primitive, {4000, 3000}, translate: {-2000, -1500}, id: :input_capture)
      end)
    end)
  end

  defp collapse_input_capture_range(%{graph: _, frame: frame} = state) do
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

  defp start_scroll(%{scrolling: :scrolling} = state), do: state
  defp start_scroll(%{scrolling: :cooling_down} = state), do: state

  defp start_scroll(state) do
    tick(state)
  end

  defp tick(state) do
    Process.send_after(self(), :tick, tick_time(state))
    state
  end

  defp parse_scroll_acceleration(nil), do: @default_acceleration
  defp parse_scroll_acceleration({x, y}), do: {x, y}
  defp parse_scroll_acceleration(x), do: {x, x}

  defp parse_scroll_speed(nil), do: @default_scroll_speed
  defp parse_scroll_speed({x, y}), do: {x, y}
  defp parse_scroll_speed(x), do: {x, x}

  defp parse_scroll_counter_pressure(nil), do: @default_counter_pressure
  defp parse_scroll_counter_pressure({x, y}), do: {x, y}
  defp parse_scroll_counter_pressure(x), do: {x, x}

  defp update_drag_state(%{drag_state: _} = state, {x, y}) do
    state
    |> Map.update!(:drag_state, fn
      %{starting_point: :none} = drag_state ->
        %{
          drag_state
          | starting_point: {:some, {x, y}},
            last_point: {:some, {x, y}},
            original_content_position: state.scroll_position
        }

      %{starting_point: {:some, _}} = drag_state ->
        %{drag_state | last_point: {:some, {x, y}}}
    end)
  end

  defp reset_drag_state(state) do
    state
    |> Map.put(:drag_state, %{
      starting_point: :none,
      last_point: :none,
      original_content_position: {0, 0}
    })
  end

  #      acceleration_state: %{
  #        acceleration: parse_scroll_acceleration(styles[:scroll_acceleration]),
  #        current_speed: {0, 0},
  #        max_speed: parse_scroll_speed(styles[:scroll_speed])
  #      },
  defp calculate_speed_x(
         x,
         %{
           last_point: {:some, {last_x, _}},
           acceleration: {acceleration, _},
           max_speed: {max_speed, _},
           current_speed: {current_speed, _}
         }
       ) do
    calculate_speed(last_x, x, acceleration, current_speed, max_speed)
  end

  defp calculate_speed_y(
         y,
         %{
           last_point: {:some, {_, last_y}},
           acceleration: {_, acceleration},
           max_speed: {_, max_speed},
           current_speed: {_, current_speed}
         }
       ) do
    calculate_speed(last_y, y, acceleration, current_speed, max_speed)
  end

  defp calculate_speed(prev_pos, pos, acceleration, speed, max_speed) do
    speed_translation = acceleration * (pos - prev_pos)

    (speed + speed_translation)
    |> min(max_speed)
    |> max(-max_speed)
  end

  defp calculate_drag_offset(
         %{drag_state: %{starting_point: {:some, starting_point}} = drag_state} = state,
         current_pos
       ) do
    current_pos
    |> v2_subtract(starting_point)
    |> v2_add(drag_state.original_content_position)
    |> (&%{state | scroll_position: cap(state, &1)}).()
  end

  defp calculate_force(
         %{drag_state: %{last_point: {:some, {last_x, last_y}}} = drag_state} = state,
         {x, y}
       ) do
    {diff_x, diff_y} = {x - last_x, y - last_y}

    update_in(state[:acceleration_state][:current_speed], fn {x, y} ->
      {calculate_force(x, diff_x), calculate_force(y, diff_y)}
    end)
  end

  defp calculate_force(0, diff), do: diff

  defp calculate_force(current, diff) when diff > 0 do
    max(diff, current)
  end

  defp calculate_force(current, diff) when diff < 0 do
    min(diff, current)
  end

  defp apply_counter_pressure(
         %{acceleration_state: %{current_speed: {v_x, v_y}, counter_pressure: {f_x, f_y}}} = state
       ) do
    f_x =
      f_x
      |> min(10)
      |> max(1.1)

    f_y =
      f_y
      |> min(10)
      |> max(1.1)

    v = {trunc(v_x / f_x), trunc(v_y / f_y)}

    put_in(state[:acceleration_state][:current_speed], v)
  end

  defp get_and_push_graph(%{graph: graph} = state) do
    push_graph(graph)
    state
  end

  defp tick_time(%{fps: fps}) do
    trunc(1000 / fps)
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

  defp v2_subtract({x1, y1}, {x2, y2}) do
    {x1 - x2, y1 - y2}
  end

  defp v2_add({x1, y1}, {x2, y2}) do
    {x1 + x2, y1 + y2}
  end
end
