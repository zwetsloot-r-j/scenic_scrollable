defmodule Scenic.Scrollable.PositionCap do
  alias Scenic.Scrollable.Direction
  alias __MODULE__

  @type v2 :: Scenic.Scrollable.v2

  @type cap :: v2 | {:horizontal, number} | {:vertical, number}

  @type settings :: %{
    optional(:max) => cap,
    optional(:min) => cap
  }

  @type t :: %PositionCap{
    max: {:some, cap} | :none,
    min: {:some, cap} | :none
  }

  defstruct max: :none,
    min: :none

  @spec init(settings) :: t
  def init(settings) do
    %PositionCap{
      max: OptionEx.return(settings.max),
      min: OptionEx.return(settings.min)
    }
  end

  @spec cap(t, v2) :: v2
  def cap(%{min: min, max: max}, coordinate) do 
    coordinate
    |> floor(min)
    |> ceil(max)
  end

  @spec floor(v2, {:some, cap} | :none) :: v2
  defp floor(coordinate, :none), do: coordinate

  defp floor({x, y}, {:some, {:horizontal, min_x}}), do: {max(x, min_x), y}

  defp floor({x, y}, {:some, {:vertical, min_y}}), do: {x, max(y, min_y)}

  defp floor({x, y}, {:some, {min_x, min_y}}), do: {max(x, min_x), max(y, min_y)}

  @spec ceil(v2, {:some, cap} | :none) :: v2
  defp ceil(coordinate, :none), do: coordinate

  defp ceil({x, y}, {:some, {:horizontal, max_x}}), do: {min(x, max_x), y}

  defp ceil({x, y}, {:some, {:vertical, max_y}}), do: {x, min(y, max_y)}

  defp ceil({x, y}, {:some, {max_x, max_y}}), do: {min(x, max_x), min(y, max_y)}

end
