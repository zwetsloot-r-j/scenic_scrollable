defmodule Scenic.Scrollable.PositionCapTest do
  use ExUnit.Case
  doctest Scenic.Scrollable.PositionCap
  alias Scenic.Scrollable.PositionCap

  setup_all context do
    {:ok, Map.put(context, :default, %PositionCap{})}
  end

  test "init", %{default: default} do
    assert PositionCap.init(%{}) == default
    assert PositionCap.init(%{max: {10, 10}}) == %PositionCap{max: {:some, {10, 10}}}

    assert PositionCap.init(%{min: {:horizontal, 0}}) == %PositionCap{
             min: {:some, {:horizontal, 0}}
           }

    assert PositionCap.init(%{max: {:vertical, 10}, min: {:vertical, 0}}) == %PositionCap{
             max: {:some, {:vertical, 10}},
             min: {:some, {:vertical, 0}}
           }
  end

  test "cap", %{default: default} do
    assert PositionCap.cap(default, {-999_999, 999_999}) == {-999_999, 999_999}

    PositionCap.init(%{min: {0, -10}, max: {10, 20}})
    |> PositionCap.cap({-999_999, 999_999})
    |> Kernel.==({0, 20})
    |> assert

    PositionCap.init(%{min: {:horizontal, 10}, max: {:horizontal, 20}})
    |> PositionCap.cap({-999_999, 999_999})
    |> Kernel.==({10, 999_999})
    |> assert

    PositionCap.init(%{min: {:horizontal, 10}, max: {:horizontal, 20}})
    |> PositionCap.cap({999_999, 999_999})
    |> Kernel.==({20, 999_999})
    |> assert

    PositionCap.init(%{min: {:vertical, -50}, max: {:vertical, -20}})
    |> PositionCap.cap({999_999, 999_999})
    |> Kernel.==({999_999, -20})
    |> assert

    # TODO proper error handling, rather than have the max cap take precedence
    PositionCap.init(%{min: {:vertical, 10}, max: {:vertical, 5}})
    |> PositionCap.cap({0, -10})
    |> Kernel.==({0, 5})
    |> assert
  end
end
