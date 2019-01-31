defmodule Scenic.Scrollable.ScrollBar do
  @type t :: any

  def init(x), do: x

  def direction(_state) do
    {0, 0}
  end

  def dragging?(_state), do: false

  def new_position(_), do: :none

  def last_position(_), do: :none
end
