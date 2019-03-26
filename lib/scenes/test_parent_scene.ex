if Mix.env() == :test do

  defmodule Scenic.Scrollable.TestParentScene do
    use Scenic.Scene
    use Scenic.Scrollable.SceneInspector, env: [:test]
    alias Scenic.Graph

    defstruct graph: Graph.build(),
      pid: nil,
      events: %{}

    def init(_, _) do
      state = %__MODULE__{pid: self()}
              |> Map.update!(:graph, &push_graph/1)
      {:ok, state}
    end

    def set_graph(pid, graph) do
      GenServer.call(pid, {:push_graph, graph})
    end

    def handle_call({:push_graph, graph}, _, state) do
      graph = push_graph(graph)
      {:reply, graph, Map.put(state, :graph, graph)}
    end
  end

end
