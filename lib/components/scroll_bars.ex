defmodule Scenic.Scrollable.ScrollBars do
  use Scenic.Component

  import Scenic.Scrollable.Components, only: [scroll_bar: 3]

  alias Scenic.Graph
  alias Scenic.Scrollable.ScrollBar
  alias Scenic.Scrollable.Direction

  @type v2 :: Scenic.Scrollable.v2

  @type settings :: %{
    width: number,
    height: number,
    content_size: v2,
    scroll_position: v2
  }

  @type style :: {:scroll_bar, Scenic.Scrollable.ScrollBar.styles}
  | {:horizontal_scroll_bar, Scenic.Scrollable.ScrollBar.styles}
  | {:vertical_scroll_bar, Scenic.Scrollable.ScrollBar.styles}
  | {:scroll_drag, Scenic.Scrollable.Drag.settings}

  @type styles :: [style]

  @type scroll_state :: :idle
    | :dragging
    | :scrolling

  @type t :: %{
    id: atom,
    graph: Graph.t,
    scroll_position: v2,
    scroll_state: scroll_state,
    pid: pid,
    horizontal_scroll_bar_pid: {:some, pid} | :none,
    vertical_scroll_bar_pid: {:some, pid} | :none,
  }

  @default_id :scroll_bars
  @default_thickness 10

  def verify(%{content_size: _, scroll_position: _} = state), do: {:ok, state}

  def verify(_), do: :invalid_input

  def init(settings, opts) do
    id = opts[:id] || @default_id
    styles = Enum.into(opts[:styles] || %{}, [])
    shared_styles = Keyword.take(styles, [:scroll_bar, :scroll_drag])

    horizontal_bar_styles = (styles[:horizontal_scroll_bar] || styles[:scroll_bar])
                            |> OptionEx.return
                            |> OptionEx.map(&Keyword.merge(&1, shared_styles))
                            |> OptionEx.map(&Keyword.put(&1, :id, :horizontal_scroll_bar))
                            |> OptionEx.map(&Keyword.put(&1, :translate, {0, settings.height}))

    vertical_bar_styles = (styles[:vertical_scroll_bar] || styles[:scroll_bar])
                          |> OptionEx.return
                          |> OptionEx.map(&Keyword.merge(&1, shared_styles))
                          |> OptionEx.map(&Keyword.put(&1, :id, :vertical_scroll_bar))
                          |> OptionEx.map(&Keyword.put(&1, :translate, {settings.width, 0}))

    {content_width, content_height} = settings.content_size
    {x, y} = settings.scroll_position

    graph = Graph.build()

    graph = horizontal_bar_styles
            |> OptionEx.map(fn styles ->
              graph
              |> scroll_bar(%{
                width: settings.width,
                height: @default_thickness,
                content_size: content_width,
                scroll_position: x,
                direction: :horizontal
              }, styles)
            end)
            |> OptionEx.or_else(graph)

    graph = vertical_bar_styles
            |> OptionEx.map(fn styles ->
              graph
              |> scroll_bar(%{
                width: @default_thickness,
                height: settings.height,
                content_size: content_height,
                scroll_position: y,
                direction: :vertical
              }, styles)
            end)
            |> OptionEx.or_else(graph)

    push_graph(graph)

    state = %{
      id: id,
      graph: graph,
      scroll_position: {x, y},
      scroll_state: :idle,
      pid: self(),
      horizontal_scroll_bar_pid: :none,
      vertical_scroll_bar_pid: :none
    }

    {send_event({:scroll_bars_initialized, state.id, state}), state}
  end

  def direction(state) do
    {x, _} = state.horizontal_scroll_bar_pid
             |> OptionEx.map(&ScrollBar.direction/1)
             |> OptionEx.or_else({0, 0})

    {_, y} = state.vertical_scroll_bar_pid
             |> OptionEx.map(&ScrollBar.direction/1)
             |> OptionEx.or_else({0, 0})

    {x, y}
  end

  def dragging?(%{scroll_state: :dragging}), do: true

  def dragging?(_), do: false

  def new_position(%{scroll_position: position}), do: {:some, position}

  def filter_event({:scroll_bar_initialized, :horizontal_scroll_bar, scroll_bar_state}, _from, state) do
    {:stop, %{state | horizontal_scroll_bar_pid: OptionEx.return(scroll_bar_state.pid)}}
  end

  def filter_event({:scroll_bar_initialized, :vertical_scroll_bar, scroll_bar_state}, _from, state) do
    {:stop, %{state | vertical_scroll_bar_pid: OptionEx.return(scroll_bar_state.pid)}}
  end

  def filter_event({:scroll_bar_button_pressed, _, scroll_bar_state}, _from, state) do
    state = update_scroll_state(state, scroll_bar_state)
    {:continue, {:scroll_bars_button_pressed, state.id, state}, state}
  end

  def filter_event({:scroll_bar_button_released, _, scroll_bar_state}, _from, state) do
    state = update_scroll_state(state, scroll_bar_state)
    {:continue, {:scroll_bars_button_released, state.id, state}, state}
  end

  def filter_event({:scroll_bar_position_change, _, _scroll_bar_state}, _from, %{scroll_state: :scrolling} = state) do
    {:stop, state}
  end

  def filter_event({:scroll_bar_position_change, _, %{direction: direction} = scroll_bar_state}, _from, state) do
    {x, y} = state.scroll_position

    ScrollBar.new_position(scroll_bar_state)
    |> Direction.from_vector_2(direction)
    |> Direction.map_horizontal(&{&1, y})
    |> Direction.map_vertical(&{x, &1})
    |> Direction.unwrap
    |> (&Map.put(state, :scroll_position, &1)).()
    |> update_scroll_state(scroll_bar_state)
    |> (&{:continue, {:scroll_bars_position_change, &1.id, &1}, &1}).()
  end

  def filter_event({:scroll_bar_scroll_end, _id, scroll_bar_state}, _from, state) do
    state = update_scroll_state(state, scroll_bar_state)

    {:continue, {:scroll_bars_scroll_end, state.id, state}, state}
  end

  def filter_event(_event, _from, state) do
    {:stop, state}
  end

  def handle_call({:update_scroll_position, {x, y}}, _, state) do
    state = %{state | scroll_position: {x, y}}

    # TODO error handling
    state.horizontal_scroll_bar_pid
    |> OptionEx.map(fn pid -> GenServer.call(pid, {:update_scroll_position, x}) end)

    state.vertical_scroll_bar_pid
    |> OptionEx.map(fn pid -> GenServer.call(pid, {:update_scroll_position, y}) end)

    {:reply, :ok, state}
  end

  defp update_scroll_state(state, scroll_bar_state) do
    %{state | scroll_state: scroll_bar_state.scroll_state}
  end

end
