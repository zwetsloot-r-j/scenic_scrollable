defmodule Scenic.Scrollable.Direction do

  @type direction :: :horizontal | :vertical

  @type t :: {:horizontal, number} | {:vertical, number}

  # @type dimensions :: %{width: width, height: height}

  def return(x, :horizontal), do: {:horizontal, x}
  def return(x, :vertical), do: {:vertical, x}

  def as_horizontal(x), do: return(x, :horizontal)
  def as_vertical(x), do: return(x, :vertical)

  def unwrap({_, x}), do: x

  def add({:horizontal, x}, {:horizontal, y}), do: {:horizontal, x + y}
  def add({:horizontal, x}, {:vertical, _}), do: {:horizontal, x}
  def add({:vertical, x}, {:vertical, y}), do: {:vertical, x + y}
  def add({:vertical, x}, {:horizontal, _}), do: {:vertical, x}

  def multiply({:horizontal, x}, {:horizontal, y}), do: {:horizontal, x * y}
  def multiply({:horizontal, x}, {:vertical, _}), do: {:horizontal, x}
  def multiply({:vertical, x}, {:vertical, y}), do: {:vertical, x * y}
  def multiply({:vertical, x}, {:horizontal, _}), do: {:vertical, x}
  def multiply(x, y, z) do
    multiply(x, y)
    |> multiply(z)
  end

  def divide({:horizontal, x}, {:horizontal, y}), do: {:horizontal, x / y}
  def divide({:horizontal, x}, {:vertical, _}), do: {:horizontal, x}
  def divide({:vertical, x}, {:vertical, y}), do: {:vertical, x / y}
  def divide({:vertical, x}, {:horizontal, _}), do: {:vertical, x}

  def map_horizontal({:horizontal, x}, fun), do: {:horizontal, fun.(x)}
  def map_horizontal(x, _), do: x

  def map_vertical({:vertical, x}, fun), do: {:vertical, fun.(x)}
  def map_vertical(x, _), do: x

  def map({direction, value}, fun), do: {direction, fun.(value)}

end
