defmodule Scenic.Scrollable.Direction do
  @type direction :: :horizontal | :vertical

  @type t :: {:horizontal, term} | {:vertical, term}

  @type v2 :: Scenic.Scrollable.v2()

  @spec return(term, direction) :: t
  def return(x, :horizontal), do: {:horizontal, x}
  def return(x, :vertical), do: {:vertical, x}

  @spec as_horizontal(term) :: t
  def as_horizontal(x), do: return(x, :horizontal)

  @spec as_vertical(term) :: t
  def as_vertical(x), do: return(x, :vertical)

  @spec to_vector_2(t) :: v2
  def to_vector_2({:horizontal, x}) when is_number(x), do: {x, 0}
  def to_vector_2({:vertical, y}) when is_number(y), do: {0, y}
  def to_vector_2(_), do: {0, 0}

  @spec from_vector_2(v2, direction) :: t
  def from_vector_2({x, _}, :horizontal), do: {:horizontal, x}
  def from_vector_2({_, y}, :vertical), do: {:vertical, y}

  @spec unwrap(t) :: term
  def unwrap({_, x}), do: x

  @spec invert(t) :: t
  def invert({:horizontal, x}), do: {:vertical, x}
  def invert({:vertical, x}), do: {:horizontal, x}

  @spec add(t, t) :: t
  def add({:horizontal, x}, {:horizontal, y}) when is_number(x) and is_number(y),
    do: {:horizontal, x + y}

  def add({:vertical, x}, {:vertical, y}) when is_number(x) and is_number(y),
    do: {:vertical, x + y}

  def add({:horizontal, x}, _), do: {:horizontal, x}
  def add({:vertical, x}, _), do: {:vertical, x}

  @spec subtract(t, t) :: t
  def subtract({:horizontal, x}, {:horizontal, y}) when is_number(x) and is_number(y),
    do: {:horizontal, x - y}

  def subtract({:vertical, x}, {:vertical, y}) when is_number(x) and is_number(y),
    do: {:vertical, x - y}

  def subtract({:horizontal, x}, _), do: {:horizontal, x}
  def subtract({:vertical, x}, _), do: {:vertical, x}

  @spec multiply(t, t) :: t
  def multiply({:horizontal, x}, {:horizontal, y}) when is_number(x) and is_number(y),
    do: {:horizontal, x * y}

  def multiply({:vertical, x}, {:vertical, y}) when is_number(x) and is_number(y),
    do: {:vertical, x * y}

  def multiply({:horizontal, x}, _), do: {:horizontal, x}
  def multiply({:vertical, x}, _), do: {:vertical, x}

  def multiply(x, y, z) do
    multiply(x, y)
    |> multiply(z)
  end

  @spec divide(t, t) :: t
  def divide({:horizontal, x}, {:horizontal, y}) when is_number(x) and is_number(y),
    do: {:horizontal, x / y}

  def divide({:vertical, x}, {:vertical, y}) when is_number(x) and is_number(y),
    do: {:vertical, x / y}

  def divide({:horizontal, x}, _), do: {:horizontal, x}
  def divide({:vertical, x}, _), do: {:vertical, x}

  @spec map_horizontal(t, (term -> term)) :: t
  def map_horizontal({:horizontal, x}, fun), do: {:horizontal, fun.(x)}
  def map_horizontal(x, _), do: x

  @spec map_vertical(t, (term -> term)) :: t
  def map_vertical({:vertical, x}, fun), do: {:vertical, fun.(x)}
  def map_vertical(x, _), do: x

  @spec map(t, (term -> term)) :: t
  def map({direction, value}, fun), do: {direction, fun.(value)}
end
