defmodule Scenic.Scrollable.ScrollBars do
  use Scenic.Component

  import Scenic.Scrollable.Components, only: [scroll_bar: 3]

  alias Scenic.Graph
  alias Scenic.Scrollable.ScrollBar

  @type v2 :: Scenic.Scrollable.v2

  @type settings :: %{
    width: number,
    height: number,
    content_size: v2,
    scroll_position: v2
  }

  @type scroll_state :: :idle
    | :dragging
    | :scrolling

  @type t :: %{
    id: atom,
    graph: Graph.t,
    scroll_position: v2,
    scroll_state: scroll_state
  }

  @default_id :scroll_bars
  @default_thickness 10

  def verify(%{content_size: _, scroll_position: _} = state), do: {:ok, state}

  def verify(_), do: :invalid_input

  def init(settings, opts) do
    styles = opts[:styles] || %{}
    id = styles[:id] || @default_id
    {content_width, content_height} = settings.content_size
    {x, y} = settings.scroll_position

    graph = Graph.build()
            |> scroll_bar(%{
              width: settings.width,
              height: @default_thickness,
              content_size: content_width,
              scroll_position: x,
              direction: :horizontal
            }, id: :horizontal_scroll_bar, translate: {0, settings.height})
            |> scroll_bar(%{
              width: @default_thickness,
              height: settings.height,
              content_size: content_height,
              scroll_position: y,
              direction: :vertical
            }, id: :vertical_scroll_bar, translate: {settings.width, 0})
            |> push_graph

    state = %{
      id: id,
      graph: graph,
      scroll_position: {x, y},
      scroll_state: :idle,
      pid: self(),
      horizontal_scrollbar_pid: nil,
      vertical_scrollbar_pid: nil
    }

    {send_event({:scroll_bars_initialized, state.id, state}), state}
  end

  def direction(_state) do
    {0, 0}
  end

  def dragging?(%{scroll_state: :dragging}), do: true

  def dragging?(_), do: false

  def new_position(%{scroll_position: position}), do: {:some, position}

  def filter_event({:scroll_bar_initialized, :horizontal_scroll_bar, scrollbar_state}, _from, state) do
    {:stop, %{state | horizontal_scrollbar_pid: scrollbar_state.pid}}
  end

  def filter_event({:scroll_bar_initialized, :vertical_scroll_bar, scrollbar_state}, _from, state) do
    {:stop, %{state | vertical_scrollbar_pid: scrollbar_state.pid}}
  end

  def filter_event({:scroll_bar_position_change, :vertical_scroll_bar, scrollbar_state}, _from, state) do
    {x, _} = state.scroll_position
    {_, y} = ScrollBar.new_position(scrollbar_state)
    state = %{state | scroll_position: {x, y}, scroll_state: :dragging}

    {:continue, {:scroll_bars_position_change, state.id, state}, state}
  end

  def filter_event({:scroll_bar_position_change, :horizontal_scroll_bar, scrollbar_state}, _from, state) do
    {_, y} = state.scroll_position
    {x, _} = ScrollBar.new_position(scrollbar_state)
    state = %{state | scroll_position: {x, y}, scroll_state: :dragging}

    {:continue, {:scroll_bars_position_change, state.id, state}, state}
  end

  def filter_event({:scroll_bar_scroll_end, _id, _scrollbar_state}, _from, state) do
    state = %{state | scroll_state: :idle}

    {:continue, {:scroll_bars_scroll_end, state.id, state}, state}
  end

  def filter_event(_event, _from, state) do
    {:stop, state}
  end

  def handle_call({:update_scroll_position, position}, _, state) do
    {x, y} = position
    state = %{state | scroll_position: position}

    # TODO error handling
    OptionEx.return(state.horizontal_scrollbar_pid)
    |> OptionEx.map(fn pid -> GenServer.call(pid, {:update_scroll_position, x}) end)

    OptionEx.return(state.vertical_scrollbar_pid)
    |> OptionEx.map(fn pid -> GenServer.call(pid, {:update_scroll_position, y}) end)

    {:reply, :ok, state}
  end

end
