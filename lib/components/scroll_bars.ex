defmodule Scenic.Scrollable.ScrollBars do
  use Scenic.Component

  import Scenic.Components, only: [button: 3]

  alias Scenic.Graph

  @type t :: %{
    graph: Graph.t,
  }

  def verify(state), do: state

  def init(_, _) do
    {:ok, %{}}
  end

  def direction(_state) do
    {0, 0}
  end

  def dragging?(_state), do: false

  def new_position(_), do: :none

  def last_position(_), do: :none
end
