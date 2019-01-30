defmodule Scenic.Scrollable.Components do
  alias Scenic.Graph
  alias Scenic.Scrollable

  def scrollable(graph, data, builder, options \\ [])

  def scrollable(%Graph{} = graph, data, builder, options) do
    add_to_graph(graph, Scrollable, Map.put(data, :builder, builder), options)
  end

  defp add_to_graph(%Graph{} = graph, module, data, options) do
    module.verify!(data)
    module.add_to_graph(graph, data, options)
  end
end
