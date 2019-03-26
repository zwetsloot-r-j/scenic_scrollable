defmodule Scenic.Scrollable.Components do
  alias Scenic.Graph
  alias Scenic.Scrollable
  alias Scenic.Scrollable.ScrollBars
  alias Scenic.Scrollable.ScrollBar
  alias Scenic.Primitive
  alias Scenic.Primitive.SceneRef

  @moduledoc """
  ## Scrollable Components

  This module contains helper functions for adding scrollable components to, or modifying scrollable components in a graph.
  Using the `Scenic.Scrollable` component will setup scrollbars and controls for you, and is recommended. However, in special cases it might be prefferable to directly use a `Scenic.Scrollable.ScrollBars` or `Scenic.Scrollable.ScrollBar` component.
  """

  @doc """
  TODO
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
  TODO

  WARNING: updating the scroll bars positions through modifying the graph leads to glitches and performance issues.
  It is recommended to directly call to the `Scenic.Scrollable.ScrollBars` process with a {:update_scroll_position, {x, y}} message for now.
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
  TODO
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
