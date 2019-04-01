defmodule Scenic.Scrollable.DirectionTest do
  use ExUnit.Case
  doctest Scenic.Scrollable.Direction
  alias Scenic.Scrollable.Direction

  test "return" do
    assert Direction.return(5, :horizontal) == {:horizontal, 5}
    assert Direction.return(6, :vertical) == {:vertical, 6}
  end

  test "as_horizontal" do
    assert Scenic.Scrollable.Direction.as_horizontal(5) == {:horizontal, 5}
    assert Scenic.Scrollable.Direction.as_horizontal("5") == {:horizontal, "5"}
  end

  test "as_vertical" do
    assert Scenic.Scrollable.Direction.as_vertical(5) == {:vertical, 5}

    assert Scenic.Scrollable.Direction.as_vertical(:non_numeric_value) ==
             {:vertical, :non_numeric_value}
  end

  test "to_vector_2" do
    v2 =
      Direction.as_horizontal(5)
      |> Direction.to_vector_2()

    assert v2 == {5, 0}

    v2 =
      Direction.as_vertical(5)
      |> Direction.to_vector_2()

    assert v2 == {0, 5}

    v2 =
      Direction.as_horizontal(:non_numeric_value)
      |> Direction.to_vector_2()

    assert v2 == {0, 0}
  end

  test "from_vector_2" do
    assert Direction.from_vector_2({3, 5}, :horizontal) == {:horizontal, 3}
    assert Direction.from_vector_2({3, 5}, :vertical) == {:vertical, 5}
  end

  test "unwrap" do
    assert Direction.unwrap({:horizontal, 4}) == 4
    assert Direction.unwrap({:vertical, :non_numeric_value}) == :non_numeric_value
  end

  test "add" do
    x = Direction.as_horizontal(5)
    y = Direction.as_horizontal(6)
    assert Direction.add(x, y) == {:horizontal, 11}

    x = Direction.as_vertical(3.5)
    y = Direction.as_vertical(7.1)
    assert Direction.add(x, y) == {:vertical, 10.6}

    x = Direction.as_horizontal(5)
    y = Direction.as_vertical(6)
    assert Direction.add(x, y) == {:horizontal, 5}

    x = Direction.as_horizontal(:non_numeric_value)
    y = Direction.as_horizontal(6)
    assert Direction.add(x, y) == {:horizontal, :non_numeric_value}
  end

  test "subtract" do
    x = Direction.as_horizontal(5)
    y = Direction.as_horizontal(6)
    assert Direction.subtract(x, y) == {:horizontal, -1}

    x = Direction.as_vertical(3.5)
    y = Direction.as_vertical(7.1)
    assert Direction.subtract(x, y) == {:vertical, 3.5 - 7.1}

    x = Direction.as_horizontal(5)
    y = Direction.as_vertical(6)
    assert Direction.subtract(x, y) == {:horizontal, 5}

    x = Direction.as_horizontal(:non_numeric_value)
    y = Direction.as_horizontal(6)
    assert Direction.subtract(x, y) == {:horizontal, :non_numeric_value}
  end

  test "multiply" do
    x = Direction.as_horizontal(5)
    y = Direction.as_horizontal(6)
    assert Direction.multiply(x, y) == {:horizontal, 30}

    x = Direction.as_vertical(3.5)
    y = Direction.as_vertical(7.1)
    assert Direction.multiply(x, y) == {:vertical, 3.5 * 7.1}

    x = Direction.as_horizontal(5)
    y = Direction.as_vertical(6)
    assert Direction.multiply(x, y) == {:horizontal, 5}

    x = Direction.as_horizontal(:non_numeric_value)
    y = Direction.as_horizontal(6)
    assert Direction.multiply(x, y) == {:horizontal, :non_numeric_value}
  end

  test "divide" do
    x = Direction.as_horizontal(5)
    y = Direction.as_horizontal(6)
    assert Direction.divide(x, y) == {:horizontal, 5 / 6}

    x = Direction.as_vertical(3.5)
    y = Direction.as_vertical(7.1)
    assert Direction.divide(x, y) == {:vertical, 3.5 / 7.1}

    x = Direction.as_horizontal(5)
    y = Direction.as_vertical(6)
    assert Direction.multiply(x, y) == {:horizontal, 5}

    x = Direction.as_horizontal(:non_numeric_value)
    y = Direction.as_horizontal(6)
    assert Direction.multiply(x, y) == {:horizontal, :non_numeric_value}
  end

  test "map_horizontal" do
    assert Direction.map_horizontal({:horizontal, 5}, &(&1 * 2)) == {:horizontal, 10}
    assert Direction.map_horizontal({:vertical, 5}, &(&1 * 2)) == {:vertical, 5}
  end

  test "map_vertical" do
    assert Direction.map_vertical({:vertical, 5.5}, &(&1 * 2)) == {:vertical, 11}
    assert Direction.map_vertical({:horizontal, 5}, &(&1 * 2)) == {:horizontal, 5}
  end

  test "map" do
    assert Direction.map({:horizontal, 5}, &(&1 * 2)) == {:horizontal, 10}
    assert Direction.map({:vertical, 5}, &(&1 * 2)) == {:vertical, 10}
  end
end
