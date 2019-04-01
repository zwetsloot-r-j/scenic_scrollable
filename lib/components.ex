defmodule Scenic.Scrollable.Components do
  alias Scenic.Graph
  alias Scenic.Scrollable
  alias Scenic.Scrollable.ScrollBars
  alias Scenic.Scrollable.ScrollBar
  alias Scenic.Primitive
  alias Scenic.Primitive.SceneRef

  @moduledoc """
  This module contains helper functions for adding scrollable components to, or modifying scrollable components in a graph.
  Using the `Scenic.Scrollable` component will setup scrollbars and controls for you, and is recommended. However, in special cases it might be prefferable to directly use a `Scenic.Scrollable.ScrollBars` or `Scenic.Scrollable.ScrollBar` component.
  """

  @doc """
  Add a `Scenic.Scrollable` to a graph.

  The `Scenic.Scrollable` component offers a way to show part of a content group bounded by a fixed rectangle or frame, and change the visible part of the content without displacing the bounded rectangle by scrolling.

  The scrollable component offers three ways to scroll, which can be used in conjunction:

  - The content can be clicked and dragged directly using a mouse.
  - Hotkeys can be set for up, down, left and right scroll directions.
  - A horizontal and a vertical scroll bar can be set up.

  Note that for the hotkeys to work, the scrollable component has to catch focus first by clicking it once with the left mouse button.

  ## Data

  `t:Scenic.Scrollable.settings/0`

  To initialize a scrollable component, a map containing `frame` and `content` elements, and a builder function are required. Further customization can be provided with optional styles.

  ### Frame

  The frame contains information about the size of the fixed rectangle shaped bounding box. It is a tuple containing the width as first element, and height as second element.

  ### Content

  The content contains information about the size and offset of the content. The offset can be used to adjust the limits of where the content can be scrolled to, and can for example be of used when the content position looks off in its {0, 0} starting position. If no offset is required, the content can be passed as a tuple containing the width as first element, and height as second element. If an offset is used, the content can be passed as a `t:Scenic.Scrollable.rect/0`, which is a map containing `x`, `y`, `width` and `height` elements.

  ## Builder

  `t:Scenic.Scrollable.builder/0`

  In addition to the required data, a scrollable component requires a builder, similar to the `Scenic.Primitive.Group` primitive. The builder is a function that takes a graph, and should return a graph with the necessary components attached to it that form the content of the scrollable component.

  ## Styles

  `t:Scenic.Scrollable.styles/0`

  Similar to the `Scenic.Primitive.Group` primitive, any style can be passed to the scrollable component, which will be passed on to the underlying components. In addition, the following styles specific to the scrollable component can be provided.

  ### scroll_position

  `t:Scenic.Scrollable.v2/0`

  The starting position of the scrollable content. This does not influence the limits to where the content can be scrolled to.

  ### scroll_acceleration

  `t:Scenic.Scrollable.Acceleration.settings/0`

  Settings regarding sensitivity of the scroll functionality. The settings are passed in a map with the following elements:

  - acceleration: number
  - mass: number
  - counter_pressure: number

  The higher number given for the acceleration, the faster the scroll movement gains speed. The default value is 20.
  The higher number given for the mass, the slower the scroll movement gains speed, and the faster it loses speed. The default value is 1.
  The higher number given for counter_pressure, the lower the maximum scroll speed, and the faster the scroll movement loses speed after the user input has stopped. The default value is 0.1.

  ### scroll_hotkeys

  `t:Scenic.Scrollable.Hotkeys.settings/0`

  A hotkey can be provided for every scroll direction to enable scrolling using the keyboard. The hotkey settings can be passed in a map with the following elements.

  - up: `t:String.t/0`
  - down: `t:String.t/0`
  - left: `t:String.t/0`
  - right: `t:String.t/0`

  The passed string can be the letter of the intended key, such as "w" or "s", or the description of a special key, such as the arrow keys "up", "down", "left" or "right".

  ### scroll_fps

  number

  Specifies the times per second the scroll content position is recalculated when it is scrolling. For environments with limited resources, it might be prudent to set a lower value than the default 30.

  ### scroll_drag

  `t:Scenic.Scrollable.Drag.settings/0`

  Options for enabling scrolling by directly dragging the content using a mouse. Buttons events on the scrollable content will take precedence over the drag functionality. Drag settings are passed in a map with the following elements:

  - mouse_buttons: [`t:Scenic.Scrollable.Drag.mouse_button/0`]

  The list of mouse buttons specifies with which mouse button the content can be dragged. Available mouse buttons are `:left`, `:right` and `:middle`. By default, the drag functionality is disabled.

  ### scroll_bar_thickness

  number

  Specify the thickness of both scroll bars.

  ### scroll_bar

  `t:Scenic.Scrollable.ScrollBar.styles/0`

  Specify the styles for both horizontal and vertical scroll bars. If different styles for each scroll bar are desired, use the `vertical_scroll_bar` and `horizontal_scroll_bar` options instead. The following styles are supported"

  - scroll_buttons: boolean
  - scroll_bar_theme: map
  - scroll_bar_radius: number
  - scroll_bar_border: number
  - scroll_drag: `t:Scenic.Scrollable.Drag.settings/0`

  The scroll_buttons boolean can be used to specify of the scroll bar should contain buttons for scrolling, in addition to the scroll bar slider. The scroll buttons are not shown by default.
  A theme can be passed using the scroll_bar_theme element to provide a set of colors for the scroll bar. For more information on themes, see the `Scenic.Primitive.Style.Theme` module. The default theme is `:light`.
  The scroll bars rounding and border can be adjusted using the scroll_bar_radius and scroll_bar_border elements respectively. The default values are 3 and 1.
  The scroll_drag settings can be provided in the same form the scrollable components scroll_drag style is provided, and can be used to specify by which mouse button the scroll bar slider can be dragged. By default, the `:left`, `:right` and `:middle` buttons are all enabled.

  ### horizontal_scroll_bar

  `t:Scenic.Scrollable.ScrollBar.styles/0`

  Specify styles for the horizontal scroll bar only. The available styles are exactly the same as explained in the above scroll_bar style section.

  ### vertical_scroll_bar

  `t:Scenic.Scrollable.ScrollBar.styles/0`

  Specify styles for the vertical scroll bar only. The available styles are exactly the same as explained in the above scroll_bar style section.

  ## Examples

      iex> graph = Scenic.Scrollable.Components.scrollable(
      ...>   Scenic.Graph.build(),
      ...>   %{
      ...>     frame: {200, 400},
      ...>     content: %{x: 0, y: 10, width: 400, height: 800}
      ...>   },
      ...>   fn graph ->
      ...>     Scenic.Primitives.text(graph, "scrollable text")
      ...>   end,
      ...>   [id: :scrollable_component_1]
      ...> )
      ...> graph.primitives[1].id
      :scrollable_component_1

      iex> graph = Scenic.Scrollable.Components.scrollable(
      ...>   Scenic.Graph.build(),
      ...>   %{
      ...>     frame: {200, 400},
      ...>     content: %{x: 0, y: 10, width: 400, height: 800}
      ...>   },
      ...>   fn graph ->
      ...>     Scenic.Primitives.text(graph, "scrollable text")
      ...>   end,
      ...>   [
      ...>     scroll_position: {-10, -50},
      ...>     scroll_acceleration: %{
      ...>       acceleration: 15,
      ...>       mass: 1.2,
      ...>       counter_pressure: 0.2
      ...>     },
      ...>     scroll_hotkeys: %{
      ...>       up: "w",
      ...>       down: "s",
      ...>       left: "a",
      ...>       right: "d"
      ...>     },
      ...>     scroll_fps: 15,
      ...>     scroll_drag: %{
      ...>       mouse_buttons: [:left]
      ...>     },
      ...>     scroll_bar_thickness: 15,
      ...>     scroll_bar: [
      ...>       scroll_buttons: true,
      ...>       scroll_bar_theme: Scenic.Primitive.Style.Theme.preset(:dark)
      ...>     ],
      ...>     translate: {50, 50},
      ...>     id: :scrollable_component_2
      ...>   ]
      ...> )
      ...> graph.primitives[1].id
      :scrollable_component_2

  """
  @spec scrollable(
          source :: Graph.t() | Primitive.t(),
          settings :: Scrollable.settings(),
          builder :: Scrollable.builder(),
          options :: Scrollable.styles()
        ) :: Graph.t() | Primitive.t()
  def scrollable(graph, settings, builder, options \\ [])

  def scrollable(%Graph{} = graph, settings, builder, options) do
    add_to_graph(graph, Scrollable, Map.put(settings, :builder, builder), options)
  end

  def scrollable(%Primitive{module: SceneRef} = p, settings, builder, options) do
    modify(p, Scrollable, Map.put(settings, :builder, builder), options)
  end

  @doc """
  Add a `Scenic.Scrollable.ScrollBars` to a graph.

  WARNING: updating the scroll bars positions through modifying the graph leads to glitches and performance issues.
  It is recommended to directly call to the `Scenic.Scrollable.ScrollBars` process with a {:update_scroll_position, {x, y}} message for now.

  The scroll bars component can be used to add a horizontal, and a vertical scroll bar pair to the graph. This component is used internally by the `Scenic.Scrollable` component, and for most cases it is recommended to use the `Scenic.Scrollable` component instead.
  ## Data

  `t:Scenic.Scrollable.ScrollBars.settings/0`

  The scroll bars require the following data for initialization:

  - width: number
  - height: number
  - content_size: `t:Scenic.Scrollable.ScrollBars.v2/0`
  - scroll_position: number
  - direction: :horizontal | :vertical

  With and height define the size of the frame, and thus correspond to the width of the horizontal, and the height of the vertical scroll bars.

  ## Styles

  `t:Scenic.Scrollable.ScrollBars.styles/0`

  The scroll bars can be customized by using the following styles:

  ### scroll_bar

  `t:Scenic.Scrollable.ScrollBar.styles/0`

  The styles to customize both scrollbars as defined in the corresponding module `Scenic.Scrollable.Scrollbar`.
  If different styles for the horizontal and vertical scroll bars are preffered, use the horizontal_scroll_bar and vertical_scroll_bar styles instead.

  ### horizontal_scroll_bar

  `t:Scenic.Scrollable.ScrollBar.styles/0`

  The styles to customize the horizontal scroll bar.

  ### vertical_scroll_bar

  `t:Scenic.Scrollable.ScrollBar.styles/0`

  The styles to customize the vertical scroll bar.

  ### scroll_drag

  `t:Scenic.Scrollable.Drag/0`

  Settings to specify which mouse buttons can be used in order to drag the scroll bar sliders.

  ### scroll_bar_thickness

  number

  Specify the height of the horizontal, and the width of the vertical scroll bars.

  ## Examples

      iex> graph = Scenic.Scrollable.Components.scroll_bars(
      ...>   Scenic.Graph.build(),
      ...>   %{
      ...>     width: 200,
      ...>     height: 200,
      ...>     content_size: {1000, 1000},
      ...>     scroll_position: {0, 0}
      ...>   },
      ...>   [
      ...>     scroll_bar: [
      ...>       scroll_buttons: true,
      ...>       scroll_bar_theme: Scenic.Primitive.Style.Theme.preset(:light),
      ...>       scroll_bar_radius: 2,
      ...>       scroll_bar_border: 2,
      ...>       scroll_drag: %{
      ...>         mouse_buttons: [:left, :right, :middle]
      ...>       }
      ...>     ],
      ...>     scroll_drag: %{
      ...>       mouse_buttons: [:left, :right, :middle]
      ...>     },
      ...>     id: :scroll_bars_component_1
      ...>   ]
      ...> )
      ...> graph.primitives[1].id
      :scroll_bars_component_1
  """
  @spec scroll_bars(
          source :: Graph.t() | Primitive.t(),
          settings :: ScrollBars.settings(),
          options :: ScrollBars.styles()
        ) :: Graph.t() | Primitive.t()
  def scroll_bars(graph, settings, options \\ [])

  def scroll_bars(%Graph{} = graph, settings, options) do
    add_to_graph(graph, ScrollBars, settings, options)
  end

  def scroll_bars(%Primitive{module: SceneRef} = p, settings, options) do
    modify(p, ScrollBars, settings, options)
  end

  @doc """
  Add a `Scenic.Scrollable.ScrollBar` to a graph.

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
  @spec scroll_bar(
          source :: Graph.t() | Primitive.t(),
          settings :: ScrollBar.settings(),
          options :: ScrollBar.styles()
        ) :: Graph.t() | Primitive.t()
  def scroll_bar(graph, data, options \\ [])

  def scroll_bar(%Graph{} = graph, data, options) do
    add_to_graph(graph, ScrollBar, data, options)
  end

  def scroll_bar(%Primitive{module: SceneRef} = p, data, options) do
    modify(p, ScrollBar, data, options)
  end

  @spec add_to_graph(Graph.t(), module, term, keyword) :: Graph.t()
  defp add_to_graph(%Graph{} = graph, module, data, options) do
    module.verify!(data)
    module.add_to_graph(graph, data, options)
  end

  @spec modify(Primitive.t(), module, term, keyword) :: Primitive.t()
  defp modify(%Primitive{module: SceneRef} = p, module, data, options) do
    module.verify!(data)
    Primitive.put(p, {module, data}, options)
  end
end
