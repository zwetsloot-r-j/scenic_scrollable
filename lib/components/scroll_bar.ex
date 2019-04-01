defmodule Scenic.Scrollable.ScrollBar do
  use Scenic.Component
  use Scenic.Scrollable.SceneInspector, env: [:test, :dev]

  import Scenic.Primitives, only: [rrect: 3, rect: 3, text: 3]

  alias Scenic.Graph
  alias Scenic.Primitive
  alias Scenic.Scrollable.Direction
  alias Scenic.Scrollable.Drag
  alias Scenic.Scrollable.PositionCap
  alias Scenic.Primitive.Style.Theme
  alias Scenic.Math.Vector2

  @moduledoc """
  The scroll bar component can be used to draw a scroll bar to the scene by adding it to the graph. The scroll bar is used internally by the `Scenic.Scrollable` component and for most cases it is recommended to use the `Scenic.Scrollable` component instead.

  The scroll bar can be setup to make use of scroll buttons at the scroll bars edges, in order to enable scrolling by pressing and holding such button, in addition to dragging the scroll bar slider control to drag, or clicking the slider background to jump.

  ## Data

  `t:Scenic.Scrollable.ScrollBar.settings/0`

  The scroll bar requires the following data for initialization:

  - width: number
  - height: number
  - content_size: number
  - scroll_position: number
  - direction: :horizontal | :vertical

  Width and height define the display size of the scroll bar.
  The content size defines the size of the scrollable content in the direction of the scroll bar. When the scroll bar is a horizontal scroll bar, the content size should correspond to the width of the content.
  The scroll position specifies the starting position of the scrollable content. Note that the scroll position corresponds to the translation of the content, rather than the scroll bar slider.
  The direction specifies if the scroll bar scrolls in horizontal, or in vertical direction.

  ## Styles

  `t:Scenic.Scrollable.ScrollBar.styles/0`

  Optional styles to customize the scroll bar. The following styles are supported:

  - scroll_buttons: boolean
  - scroll_bar_theme: map
  - scroll_bar_radius: number
  - scroll_bar_border: number
  - scroll_drag: `t:Scenic.Scrollable.Drag.settings/0`

  The scroll_buttons boolean can be used to specify of the scroll bar should contain buttons for scrolling, in addition to the scroll bar slider. The scroll buttons are not shown by default.
  A theme can be passed using the scroll_bar_theme element to provide a set of colors for the scroll bar. For more information on themes, see the `Scenic.Primitive.Style.Theme` module. The default theme is `:light`.
  The scroll bars rounding and border can be adjusted using the scroll_bar_radius and scroll_bar_border elements respectively. The default values are 3 and 1.
  The scroll_drag settings can be provided to specify by which mouse button the scroll bar slider can be dragged. By default, the `:left`, `:right` and `:middle` buttons are all enabled.

  ## Examples

      iex> graph = Scenic.Scrollable.Components.scroll_bar(
      ...>   Scenic.Graph.build(),
      ...>   %{
      ...>     width: 200,
      ...>     height: 10,
      ...>     content_size: 1000,
      ...>     scroll_position: 0,
      ...>     direction: :horizontal
      ...>   },
      ...>   [id: :scroll_bar_component_1]
      ...> )
      ...> graph.primitives[1].id
      :scroll_bar_component_1

      iex> graph = Scenic.Scrollable.Components.scroll_bar(
      ...>   Scenic.Graph.build(),
      ...>   %{
      ...>     width: 200,
      ...>     height: 10,
      ...>     content_size: 1000,
      ...>     scroll_position: 0,
      ...>     direction: :horizontal
      ...>   },
      ...>   [
      ...>     scroll_buttons: true,
      ...>     scroll_bar_theme: Scenic.Primitive.Style.Theme.preset(:dark),
      ...>     scroll_bar_radius: 4,
      ...>     scroll_bar_border: 1,
      ...>     scroll_drag: %{
      ...>       mouse_buttons: [:left, :right]
      ...>     },
      ...>     id: :scroll_bar_component_2
      ...>   ]
      ...> )
      ...> graph.primitives[1].id
      :scroll_bar_component_2

  """

  @typedoc """
  Specifies the direction in which the scroll bar affects the content.
  A direction can be either :horizontal or :vertical.
  """
  @type scroll_direction :: Direction.direction()

  @typedoc """
  Data structure representing a vector 2, in the form of an {x, y} tuple.
  """
  @type v2 :: Scenic.Scrollable.v2()

  @typedoc """
  Data structure representing a rectangle.
  """
  @type rect :: Scenic.Scrollable.rect()

  @typedoc """
  The data required to initialize a scroll bar component.
  The scroll bar requires the following data for initialization:

  - width: number
  - height: number
  - content_size: number
  - scroll_position: number
  - direction: :horizontal | :vertical

  Width and height define the display size of the scroll bar.
  The content size defines the size of the scrollable content in the direction of the scroll bar. When the scroll bar is a horizontal scroll bar, the content size should correspond to the width of the content.
  The scroll position specifies the starting position of the scrollable content. Note that the scroll position corresponds to the translation of the content, rather than the scroll bar slider.
  The direction specifies if the scroll bar scrolls in horizontal, or in vertical direction.
  """
  @type settings :: %{
          width: number,
          height: number,
          content_size: number,
          scroll_position: number,
          direction: scroll_direction
        }

  @typedoc """
  Atom representing a mouse button.
  """
  @type mouse_button ::
          :left
          | :right
          | :middle

  @typedoc """
  The optional styles with which the scroll bar component can be customized. See this modules top section for a more detailed explanation of every style.
  """
  @type style ::
          {:scroll_buttons, boolean}
          # TODO use Scenic.Theme.t when/if it gets defined
          | {:scroll_bar_theme, %{}}
          | {:scroll_bar_radius, number}
          | {:scroll_bar_border, number}
          | {:scroll_drag, Drag.settings()}
          # TODO enable images as buttons

  @typedoc """
  A collection of optional styles with which the scroll bar component can be customized. See `t:Scenic.Scrollable.ScrollBar.style/0` and this modules top section for more information.
  """
  @type styles :: [style]

  @typedoc """
  A map containing information about the scroll button pressed states.
  """
  @type scroll_buttons :: %{
          scroll_button_1: :pressed | :released,
          scroll_button_2: :pressed | :released
        }

  @typedoc """
  The state with which the scroll bar components GenServer is running.
  """
  @type t :: %__MODULE__{
          id: atom,
          graph: Graph.t(),
          width: Direction.t(),
          height: Direction.t(),
          frame_size: Direction.t(),
          content_size: Direction.t(),
          scroll_position: Direction.t(),
          last_scroll_position: Direction.t(),
          direction: scroll_direction,
          drag_state: Drag.t(),
          position_cap: PositionCap.t(),
          scroll_buttons: :none | {:some, scroll_buttons},
          scroll_bar_slider_background: :pressed | :released,
          scroll_state: :idle | :scrolling | :dragging,
          styles: styles,
          pid: pid
        }

  defstruct id: :scroll_bar,
            graph: Graph.build(),
            width: {:horizontal, 0},
            height: {:vertical, 0},
            frame_size: {:horizontal, 0},
            content_size: {:horizontal, 0},
            scroll_position: {:horizontal, 0},
            last_scroll_position: {:horizontal, 0},
            direction: :horizontal,
            drag_state: %Drag{},
            position_cap: %PositionCap{},
            scroll_buttons: :none,
            scroll_bar_slider_background: :released,
            scroll_state: :idle,
            styles: [],
            pid: nil

  @default_drag_settings %{mouse_buttons: [:left, :right, :middle]}
  @default_button_radius 3
  @default_stroke_size 1
  @default_id :scroll_bar

  # PUBLIC API

  @doc """
  Find out the direction in which the content should be scrolled based on the scroll buttons currently being pressed.
  Although the scroll bar will move along a single axis, a vector 2 is returned to facilitate translation calculations of the content.
  """
  @spec direction(pid | t) :: v2
  def direction(pid) when is_pid(pid) do
    GenServer.call(pid, :direction)
  end

  def direction(%{
        scroll_buttons: {:some, %{scroll_button_1: :pressed, scroll_button_2: :released}},
        direction: direction
      }) do
    Direction.return(1, direction)
    |> Direction.to_vector_2()
  end

  def direction(%{
        scroll_buttons: {:some, %{scroll_button_1: :released, scroll_button_2: :pressed}},
        direction: direction
      }) do
    Direction.return(-1, direction)
    |> Direction.to_vector_2()
  end

  def direction(_), do: {0, 0}

  @doc """
  Find out if the scroll bar is currently being dragged by the user.
  """
  @spec dragging?(t) :: boolean
  def dragging?(state), do: Drag.dragging?(state.drag_state)

  @doc """
  Find the latest position the scrollable content should be updated with.
  The position corresponds to the contents translation, rather than the scroll bars drag control translation.
  """
  @spec new_position(t) :: v2
  def new_position(state) do
    scroll_position_vector2(state)
  end

  # CALLBACKS

  @impl Scenic.Scene
  def init(
        %{width: width, height: height, content_size: content_size, direction: direction} =
          settings,
        opts
      ) do
    styles = Enum.into(opts[:styles] || %{}, [])
    scroll_buttons = styles[:scroll_buttons] || false

    state =
      %__MODULE__{
        id: opts[:id] || @default_id,
        direction: direction,
        content_size: Direction.return(content_size, direction),
        frame_size: Direction.from_vector_2({width, height}, direction),
        scroll_position: Direction.return(settings.scroll_position, direction),
        last_scroll_position: Direction.return(settings.scroll_position, direction),
        drag_state: Drag.init(styles[:scroll_drag] || @default_drag_settings),
        scroll_buttons:
          OptionEx.from_bool(scroll_buttons, %{
            scroll_button_1: :released,
            scroll_button_2: :released
          }),
        styles: styles,
        pid: self()
      }
      |> init_size(width, height)
      |> init_position_cap()
      |> init_graph()

    {send_event({:scroll_bar_initialized, state.id, state}), state}
  end

  @impl Scenic.Component
  def verify(
        %{
          width: width,
          height: height,
          content_size: content_size,
          scroll_position: scroll_position,
          direction: direction
        } = settings
      )
      when is_number(width) and is_number(height) and is_number(content_size) and
             is_number(scroll_position) do
    if direction == :horizontal or direction == :vertical do
      {:ok, settings}
    else
      :invalid_input
    end
  end

  def verify(_), do: :invalid_input

  @impl Scenic.Scene
  def handle_input(
        {:cursor_button, {button, :press, _, position}},
        %{id: :scroll_bar_slider_drag_control},
        state
      ) do
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
    state =
      Map.update!(state, :scroll_buttons, fn scroll_buttons ->
        OptionEx.map(scroll_buttons, &%{&1 | scroll_button_1: :released})
      end)
      |> update

    :ok = send_event({:scroll_bar_button_released, state.id, state})

    {:noreply, state}
  end

  def handle_input({:cursor_button, {_button, :release, _, _}}, %{id: :scroll_button_2}, state) do
    state =
      Map.update!(state, :scroll_buttons, fn scroll_buttons ->
        OptionEx.map(scroll_buttons, &%{&1 | scroll_button_2: :released})
      end)
      |> update

    :ok = send_event({:scroll_bar_button_released, state.id, state})

    {:noreply, state}
  end

  def handle_input(
        {:cursor_button, {button, :release, _, position}},
        %{id: :input_capture},
        state
      ) do
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
    state =
      Map.update!(state, :scroll_buttons, fn scroll_buttons ->
        OptionEx.map(scroll_buttons, &%{&1 | scroll_button_1: :pressed})
      end)
      |> update

    :ok = send_event({:scroll_bar_button_pressed, state.id, state})

    {:noreply, state}
  end

  def handle_input({:cursor_button, {_button, :press, _, _}}, %{id: :scroll_button_2}, state) do
    state =
      Map.update!(state, :scroll_buttons, fn scroll_buttons ->
        OptionEx.map(scroll_buttons, &%{&1 | scroll_button_2: :pressed})
      end)
      |> update

    :ok = send_event({:scroll_bar_button_pressed, state.id, state})

    {:noreply, state}
  end

  def handle_input({:cursor_button, {_button, :press, _, _position}}, _, state) do
    %{state | scroll_bar_slider_background: :pressed}
    |> update
    |> (&{:noreply, &1}).()
  end

  def handle_input(
        {:cursor_button, {_button, :release, _, position}},
        _,
        %{direction: direction} = state
      ) do
    scroll_position =
      Direction.from_vector_2(position, direction)
      |> Direction.map_horizontal(fn pos -> pos - button_width(state) / 2 end)
      |> Direction.map_vertical(fn pos -> pos - button_height(state) / 2 end)

    scroll_position = local_to_world(state, scroll_position)

    state
    |> Map.put(:scroll_bar_slider_background, :released)
    |> Map.put(:last_scroll_position, state.scroll_position)
    |> Map.put(:scroll_position, scroll_position)
    |> update
    |> (&{:noreply, &1}).()
  end

  def handle_input({:cursor_exit, _}, _, state) do
    Map.update!(state, :scroll_buttons, fn scroll_buttons ->
      OptionEx.map(
        scroll_buttons,
        &%{&1 | scroll_button_2: :released, scroll_button_1: :released}
      )
    end)
    |> update
    |> (&{:noreply, &1}).()
  end

  def handle_input(_event, _, state) do
    {:noreply, state}
  end

  # no callback on the `Scenic.Scene` and no GenServer @behaviour, so impl will not work
  @spec handle_call(request :: term(), GenServer.from(), state :: term()) ::
          {:reply, reply :: term, new_state :: term}
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

  def handle_call(msg, _, state) do
    {:reply, {:error, {:unexpected_message, msg}}, state}
  end

  @impl Scenic.Scene
  def filter_event(_, _, state), do: {:stop, state}

  # INITIALIZERS

  @spec init_size(t, width :: number, height :: number) :: t
  defp init_size(%{scroll_buttons: :none} = state, width, height) do
    state
    |> Map.put(:width, Direction.as_horizontal(width))
    |> Map.put(:height, Direction.as_vertical(height))
  end

  defp init_size(%{scroll_buttons: {:some, _}} = state, width, height) do
    width = Direction.as_horizontal(width)
    height = Direction.as_vertical(height)

    displacement =
      scroll_bar_displacement(
        state
        |> Map.put(:width, width)
        |> Map.put(:height, height)
      )

    button_size_difference = Direction.map(displacement, &(&1 * 2))

    state
    |> Map.put(:width, Direction.subtract(width, button_size_difference))
    |> Map.put(:height, Direction.subtract(height, button_size_difference))
  end

  @spec init_scroll_buttons(t) :: t
  defp init_scroll_buttons(%{scroll_buttons: :none} = state), do: state

  defp init_scroll_buttons(%{graph: graph, direction: direction} = state) do
    theme = state.styles[:scroll_bar_theme] || Theme.preset(:light)
    radius = state.styles[:scroll_bar_radius] || @default_button_radius

    {btn1_text, btn2_text} =
      Direction.return({"", ""}, direction)
      |> Direction.map_horizontal(fn {left, right} -> {left <> "<", right <> ">"} end)
      |> Direction.map_vertical(fn {up, down} -> {up <> "^", down <> "v"} end)
      |> Direction.unwrap()

    size = scroll_button_size(state)

    button_2_position =
      Direction.return(size, direction)
      |> Direction.add(state.width)
      |> Direction.add(state.height)
      |> Direction.to_vector_2()

    graph
    |> rrect(
      {size, size, radius},
      id: :scroll_button_1,
      translate: {0, 0},
      fill: theme.background
    )
    |> text(
      btn1_text,
      font_size: 15,
      fill: theme.text,
      translate: {size * 0.5, size * 1},
      text_align: :center
    )
    |> rrect(
      {size, size, radius},
      id: :scroll_button_2,
      translate: button_2_position,
      fill: theme.background
    )
    |> text(
      btn2_text,
      font_size: 15,
      fill: theme.text,
      translate: Vector2.add(button_2_position, {size * 0.5, size * 1}),
      text_align: :center
    )
    |> (&%{state | graph: &1}).()
  end

  @spec init_position_cap(t) :: t
  defp init_position_cap(%{direction: direction} = state) do
    max =
      Direction.return(0, direction)
      |> Direction.add(state.width)
      |> Direction.add(state.height)
      |> Direction.map_horizontal(fn width ->
        width - button_width(state) + scroll_button_size(state)
      end)
      |> Direction.map_vertical(fn height ->
        height - button_height(state) + scroll_button_size(state)
      end)
      |> Direction.to_vector_2()

    min =
      scroll_bar_displacement(state)
      |> Direction.to_vector_2()

    Map.put(state, :position_cap, PositionCap.init(%{min: min, max: max}))
  end

  @spec init_graph(t) :: t
  defp init_graph(state) do
    width = Direction.unwrap(state.width)
    height = Direction.unwrap(state.height)

    theme = state.styles[:scroll_bar_theme] || Theme.preset(:light)
    radius = state.styles[:scroll_bar_radius] || @default_button_radius
    border = state.styles[:scroll_bar_border] || @default_stroke_size

    Map.update!(state, :graph, fn graph ->
      graph
      |> rrect(
        {width, height, radius},
        id: :scroll_bar_slider_background,
        fill: theme.border,
        stroke: {border, theme.background},
        translate: Direction.to_vector_2(scroll_bar_displacement(state))
      )
      |> rrect(
        {button_width(state), button_height(state), radius},
        id: :scroll_bar_slider_drag_control,
        translate: local_scroll_position_vector2(state),
        fill: theme.background
      )
      |> rect({0, 0}, id: :input_capture)
    end)
    |> init_scroll_buttons
    |> get_and_push_graph
  end

  # UPDATERS

  @spec update(t) :: t
  defp update(state) do
    state
    |> update_scroll_state
    |> update_scroll_position
    |> update_graph_drag_control_position
    |> update_control_colors
    |> get_and_push_graph
    |> send_position_change_event
  end

  @spec update_scroll_state(t) :: t
  defp update_scroll_state(state) do
    verify_scrolling(state)
    |> OptionEx.or_try(fn -> verify_dragging(state) end)
    |> OptionEx.or_else(:idle)
    |> (&%{state | scroll_state: &1}).()
  end

  @spec update_scroll_position(t) :: t
  defp update_scroll_position(%{direction: direction} = state) do
    Drag.new_position(state.drag_state)
    |> OptionEx.map(&Direction.from_vector_2(&1, direction))
    |> OptionEx.map(&Direction.map(&1, fn position -> local_to_world(state, position) end))
    |> OptionEx.map(&%{state | last_scroll_position: state.scroll_position, scroll_position: &1})
    |> OptionEx.or_else(state)
  end

  @spec update_graph_drag_control_position(t) :: t
  defp update_graph_drag_control_position(state) do
    update_graph_component(state, :scroll_bar_slider_drag_control, fn primitive ->
      Map.update(primitive, :transforms, %{}, fn transforms ->
        Map.put(transforms, :translate, local_scroll_position_vector2(state))
      end)
    end)
  end

  @spec update_graph(t, (Graph.t() -> Graph.t())) :: t
  defp update_graph(state, updater) do
    state
    |> Map.update!(:graph, updater)
  end

  @spec update_graph_component(t, id :: term, (Primitive.t() -> Primitive.t())) :: t
  defp update_graph_component(state, id, updater) do
    update_graph(state, fn graph ->
      Graph.modify(graph, id, updater)
    end)
  end

  @spec update_control_colors(t) :: t
  defp update_control_colors(state) do
    theme = state.styles[:scroll_bar_theme] || Theme.preset(:light)

    drag_control_color =
      Drag.dragging?(state.drag_state)
      |> OptionEx.from_bool(theme.active)
      |> OptionEx.or_else(theme.background)

    scroll_bar_slider_background_color =
      OptionEx.from_bool(state.scroll_bar_slider_background == :pressed, theme.text)
      |> OptionEx.or_else(theme.border)

    graph =
      state.graph
      |> Graph.modify(
        :scroll_bar_slider_drag_control,
        &Primitive.put_style(&1, :fill, drag_control_color)
      )
      |> Graph.modify(
        :scroll_bar_slider_background,
        &Primitive.put_style(&1, :fill, scroll_bar_slider_background_color)
      )

    graph =
      state.scroll_buttons
      |> OptionEx.map(fn scroll_buttons ->
        button1_color =
          OptionEx.from_bool(scroll_buttons.scroll_button_1 == :pressed, theme.active)
          |> OptionEx.or_else(theme.background)

        button2_color =
          OptionEx.from_bool(scroll_buttons.scroll_button_2 == :pressed, theme.active)
          |> OptionEx.or_else(theme.background)

        graph
        |> Graph.modify(:scroll_button_1, &Primitive.put_style(&1, :fill, button1_color))
        |> Graph.modify(:scroll_button_2, &Primitive.put_style(&1, :fill, button2_color))
      end)
      |> OptionEx.or_else(graph)

    Map.put(state, :graph, graph)
  end

  @spec verify_scrolling(t) :: {:some, :scrolling} | :none
  defp verify_scrolling(%{scroll_buttons: {:some, buttons}}) do
    OptionEx.from_bool(buttons.scroll_button_1 == :pressed, :scrolling)
    |> OptionEx.or_try(fn ->
      OptionEx.from_bool(buttons.scroll_button_2 == :pressed, :scrolling)
    end)
  end

  defp verify_scrolling(_), do: :none

  @spec verify_dragging(t) :: {:some, :dragging} | :none
  defp verify_dragging(state) do
    OptionEx.from_bool(Drag.dragging?(state.drag_state), :dragging)
  end

  # UTILITY

  # MEMO: scrolling using directional buttons will only set the direction, the position of the scroll controls will be updated by the :update_scroll_position call called back by the scrollable component
  @spec send_position_change_event(t) :: t
  defp send_position_change_event(%{scroll_state: :scrolling} = state), do: state

  defp send_position_change_event(%{last_scroll_position: last, scroll_position: current} = state) do
    OptionEx.from_bool(last != current, state)
    |> OptionEx.map(fn state ->
      :ok = send_event({:scroll_bar_position_change, state.id, state})
      state
    end).()
    |> OptionEx.or_else(state)
  end

  @spec get_and_push_graph(t) :: t
  defp get_and_push_graph(%{graph: graph} = state) do
    push_graph(graph)
    state
  end

  # SIZE CALCULATIONS

  @spec scroll_button_size(any) :: number
  defp scroll_button_size(%{scroll_buttons: :none}), do: 0

  defp scroll_button_size(%{width: width, height: height, direction: direction}) do
    Direction.return(1, direction)
    |> Direction.invert()
    |> Direction.multiply(width)
    |> Direction.multiply(height)
    |> Direction.unwrap()
  end

  @spec button_width(t) :: number
  defp button_width(%{direction: :horizontal} = state) do
    Direction.divide(state.frame_size, state.content_size)
    |> Direction.multiply(state.width)
    |> Direction.unwrap()
  end

  defp button_width(state), do: Direction.unwrap(state.width)

  @spec button_height(t) :: number
  defp button_height(%{direction: :vertical} = state) do
    Direction.divide(state.frame_size, state.content_size)
    |> Direction.multiply(state.height)
    |> Direction.unwrap()
  end

  defp button_height(state), do: Direction.unwrap(state.height)

  @spec width_factor(t) :: number
  defp width_factor(%{content_size: {:horizontal, size}, width: {_, width}}) do
    width / size
  end

  defp width_factor(_), do: 1

  @spec height_factor(t) :: number
  defp height_factor(%{content_size: {:vertical, size}, height: {_, height}}) do
    height / size
  end

  defp height_factor(_), do: 1

  # POSITION CALCULATIONS

  @spec scroll_bar_displacement(t) :: Direction.t()
  defp scroll_bar_displacement(%{direction: direction} = state) do
    scroll_button_size(state)
    |> Direction.return(direction)
  end

  @spec scroll_position_vector2(t) :: v2
  defp scroll_position_vector2(state) do
    Direction.to_vector_2(state.scroll_position)
  end

  @spec local_scroll_position_vector2(t) :: v2
  defp local_scroll_position_vector2(state) do
    world_to_local(state, scroll_position_vector2(state))
  end

  @spec local_to_world(t, Direction.t() | number | v2) :: Direction.t() | number | v2
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

  @spec world_to_local(t, number | v2) :: number | v2
  defp world_to_local(%{direction: direction} = state, {x, y}) do
    position =
      Direction.from_vector_2({x, y}, direction)
      |> Direction.map(&world_to_local(state, &1))
      |> Direction.to_vector_2()

    PositionCap.cap(state.position_cap, position)
  end

  defp world_to_local(%{direction: :horizontal} = state, x),
    do: -x * width_factor(state) + scroll_button_size(state)

  defp world_to_local(%{direction: :vertical} = state, y),
    do: -y * height_factor(state) + scroll_button_size(state)
end
