defmodule Scenic.Scrollable.PositionCap do
  alias __MODULE__

  @moduledoc """
  Module for applying limits to a position.
  """

  @typedoc """
  A vector 2 in the form of {x, y}
  """
  @type v2 :: Scenic.Scrollable.v2()

  @typedoc """
  Data structure representing a minimum, or maximum cap which values will be compared against.
  The cap can be either a `t:v2/0` or a `t:Scenic.Scrollable.Direction.t/0`.
  By using a `t:Scenic.Scrollable.Direction/0` it is possible to cap a position only for either its x, or its y value.
  """
  @type cap :: v2 | {:horizontal, number} | {:vertical, number}

  @typedoc """
  The settings with which to initialize a `t:Scenic.Scrollable.PositionCap.t`.
  Both min and max caps are optional, and can be further limited to only the x, or y axes by passing in a `t:Scenic.Scrollable.Direction/0` rather than a `t:v2/0`.
  """
  @type settings :: %{
          optional(:max) => cap,
          optional(:min) => cap
        }

  @typedoc """
  A struct representing a position cap. Positions in the form of a `t:v2/0` can be compared against, and increased or reduced to the capped values by using the `cap/2` function.
  """
  @type t :: %PositionCap{
          max: {:some, cap} | :none,
          min: {:some, cap} | :none
        }

  defstruct max: :none,
            min: :none

  @doc """
  Initializes a `t:Scenic.Scrollable.PositionCap.t/0` according to the provided `t:Scenic.Scrollable.PositionCap.settings/0`.
  """
  @spec init(settings) :: t
  def init(settings) do
    # TODO add validation in order to prevent a max value that is smaller than the min value
    # In the current code, the max value will take precedence in such case
    %PositionCap{
      max: OptionEx.return(settings[:max]),
      min: OptionEx.return(settings[:min])
    }
  end

  @doc """
  Compare the upper and lower limits set in the `t:Scenic.Scrollable.PositionCap.t/0` against the `t:v2/0` provided, and adjusts the `t:v2/0` according to those limits.
  """
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
