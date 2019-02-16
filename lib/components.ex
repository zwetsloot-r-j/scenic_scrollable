defmodule Scenic.Scrollable.Components do
  alias Scenic.Graph
  alias Scenic.Scrollable
  alias Scenic.Scrollable.ScrollBars
  alias Scenic.Scrollable.ScrollBar
  alias Scenic.Primitive
  alias Scenic.Primitive.SceneRef

  def scrollable(graph, data, builder, options \\ [])

  def scrollable(%Graph{} = graph, data, builder, options) do
    add_to_graph(graph, Scrollable, Map.put(data, :builder, builder), options)
  end

  def scrollable(%Primitive{module: SceneRef} = p, data, builder, options) do
    modify(p, Scrollable, Map.put(data, :builder, builder), options)
  end

  def scroll_bars(graph, data, options \\ [])

  def scroll_bars(%Graph{} = graph, data, options) do
    add_to_graph(graph, ScrollBars, data, options)
  end

  def scroll_bars(%Primitive{module: SceneRef} = p, data, options) do
    modify(p, ScrollBars, data, options)
  end

  def scroll_bar(graph, data, options \\ [])

  def scroll_bar(%Graph{} = graph, data, options) do
    add_to_graph(graph, ScrollBar, data, options)
  end

  def scroll_bar(%Primitive{module: SceneRef} = p, data, options) do
    modify(p, ScrollBar, data, options)
  end

  defp add_to_graph(%Graph{} = graph, module, data, options) do
    module.verify!(data)
    module.add_to_graph(graph, data, options)
  end

  defp modify(%Primitive{module: SceneRef} = p, mod, data, options) do
    mod.verify!(data)
    Primitive.put(p, {mod, data}, options)
  end
end
