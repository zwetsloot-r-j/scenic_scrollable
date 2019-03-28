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

    def clear_event_history() do
      {:ok, {pid, _}} = __MODULE__.inspect()
      clear_event_history(pid)
    end

    def clear_event_history(pid) do
      GenServer.call(pid, :clear_event_history)
    end

    def has_event_fired?(event) do
      {:ok, {pid, _}} = __MODULE__.inspect()
      GenServer.call(pid, {:has_event_fired?, event})
    end

    def handle_call({:push_graph, graph}, _, state) do
      graph = push_graph(graph)
      {:reply, graph, Map.put(state, :graph, graph)}
    end

    def handle_call(:clear_event_history, _from, state) do
      state = %{state | events: %{}}
      {:reply, {:ok, state}, state}
    end

    def handle_call({:has_event_fired?, event}, _from, state) do
      {:reply, Map.has_key?(state.events, event), state}
    end

    def filter_event(event, _from, state) do
      {:stop, %{state | events: Map.put(state.events, elem(event, 0), event)}}
    end
  end

end
