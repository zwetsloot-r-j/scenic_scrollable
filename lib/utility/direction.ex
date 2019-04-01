defmodule Scenic.Scrollable.Direction do
  @moduledoc """
  Utility module for limiting certain operations along a certain direction only. A value can be connected to either horizontal or vertical directions.
  """

  @typedoc """
  The directions a value can be associated with.
  """
  @type direction :: :horizontal | :vertical

  @typedoc """
  The Direction type. A value can be either associated with the horizontal or the vertical direction, by pairing the :horizontal or :vertical atoms with the value in a tuple.
  """
  @type t :: {:horizontal, term} | {:vertical, term}

  @typedoc """
  Data structure representing a vector 2, in the form of an {x, y} tuple.
  """
  @type v2 :: Scenic.Scrollable.v2()

  @doc """
  Associate a value with a direction.

  ## Examples

      iex> Scenic.Scrollable.Direction.return(5, :horizontal)
      {:horizontal, 5}

      iex> Scenic.Scrollable.Direction.return(6, :vertical)
      {:vertical, 6}
  """
  @spec return(term, direction) :: t
  def return(x, :horizontal), do: {:horizontal, x}
  def return(x, :vertical), do: {:vertical, x}

  @doc """
  Associate a value with the horizontal direction.

  ## Examples

      iex> Scenic.Scrollable.Direction.as_horizontal(5)
      {:horizontal, 5}
  """
  @spec as_horizontal(term) :: t
  def as_horizontal(x), do: return(x, :horizontal)

  @doc """
  Associate a value with the vertical direction.

  ## Examples

      iex> Scenic.Scrollable.Direction.as_vertical(6)
      {:vertical, 6}
  """
  @spec as_vertical(term) :: t
  def as_vertical(x), do: return(x, :vertical)

  @doc """
  Convert a `t:Scenic.Scrollable.Direction.t/0` to a `t:Scenic.Math.vector_2/0`.
  If the value is non numeric, the vector {0, 0} will be returned.

  ## Examples

      iex> Scenic.Scrollable.Direction.as_horizontal(5)
      ...> |> Scenic.Scrollable.Direction.to_vector_2
      {5, 0}

      iex> Scenic.Scrollable.Direction.as_vertical(5)
      ...> |> Scenic.Scrollable.Direction.to_vector_2
      {0, 5}

      iex> Scenic.Scrollable.Direction.as_horizontal(:non_numeric_value)
      ...> |> Scenic.Scrollable.Direction.to_vector_2
      {0, 0}
  """
  @spec to_vector_2(t) :: v2
  def to_vector_2({:horizontal, x}) when is_number(x), do: {x, 0}
  def to_vector_2({:vertical, y}) when is_number(y), do: {0, y}
  def to_vector_2(_), do: {0, 0}

  @doc """
  Create a `t:Scenic.Scrollable.Direction.t/0` from a `t:Scenic.Math.vector_2/0`.

  ## Examples

      iex> Scenic.Scrollable.Direction.from_vector_2({3, 5}, :horizontal)
      {:horizontal, 3}

      iex> Scenic.Scrollable.Direction.from_vector_2({3, 5}, :vertical)
      {:vertical, 5}
  """
  @spec from_vector_2(v2, direction) :: t
  def from_vector_2({x, _}, :horizontal), do: {:horizontal, x}
  def from_vector_2({_, y}, :vertical), do: {:vertical, y}

  @doc """
  Obtain the inner value from a `t:Scenic.Scrollable.Direction.t/0`.

  ## Examples

      iex> Scenic.Scrollable.Direction.as_horizontal(5)
      ...> |> Scenic.Scrollable.Direction.unwrap
      5
  """
  @spec unwrap(t) :: term
  def unwrap({_, x}), do: x

  @doc """
  Convert a horizontal `t:Scenic.Scrollable.Direction.t/0` to a vertical one, and vice versa.

  ## Examples

      iex> Scenic.Scrollable.Direction.as_horizontal(5)
      ...> |> Scenic.Scrollable.Direction.invert
      {:vertical, 5}
  """
  @spec invert(t) :: t
  def invert({:horizontal, x}), do: {:vertical, x}
  def invert({:vertical, x}), do: {:horizontal, x}

  @doc """
  Add two `t:Scenic.Scrollable.Direction.t/0` values. Only values associated with the same direction will be added. Non numeric values are ignored.

  ## Examples

      iex> five = Scenic.Scrollable.Direction.as_horizontal(5)
      ...> six = Scenic.Scrollable.Direction.as_horizontal(6)
      ...> Scenic.Scrollable.Direction.add(five, six)
      {:horizontal, 11}

      iex> three = Scenic.Scrollable.Direction.as_vertical(3)
      ...> seven = Scenic.Scrollable.Direction.as_vertical(7)
      ...> Scenic.Scrollable.Direction.add(three, seven)
      {:vertical, 10}

      iex> five = Scenic.Scrollable.Direction.as_horizontal(5)
      ...> six = Scenic.Scrollable.Direction.as_vertical(6)
      ...> Scenic.Scrollable.Direction.add(five, six)
      {:horizontal, 5}

      iex> non_numeric_value = Scenic.Scrollable.Direction.as_horizontal(:non_numeric_value)
      ...> six = Scenic.Scrollable.Direction.as_vertical(6)
      ...> Scenic.Scrollable.Direction.add(non_numeric_value, six)
      {:horizontal, :non_numeric_value}
  """
  @spec add(t, t) :: t
  def add({:horizontal, x}, {:horizontal, y}) when is_number(x) and is_number(y),
    do: {:horizontal, x + y}

  def add({:vertical, x}, {:vertical, y}) when is_number(x) and is_number(y),
    do: {:vertical, x + y}

  def add({:horizontal, x}, _), do: {:horizontal, x}
  def add({:vertical, x}, _), do: {:vertical, x}

  @doc """
  Subtract two `t:Scenic.Scrollable.Direction.t/0` values. Only values associated with the same direction will be subtracted. Non numeric values are ignored.

  ## Examples

      iex> five = Scenic.Scrollable.Direction.as_horizontal(5)
      ...> six = Scenic.Scrollable.Direction.as_horizontal(6)
      ...> Scenic.Scrollable.Direction.subtract(five, six)
      {:horizontal, -1}

      iex> three = Scenic.Scrollable.Direction.as_vertical(3)
      ...> seven = Scenic.Scrollable.Direction.as_vertical(7)
      ...> Scenic.Scrollable.Direction.subtract(three, seven)
      {:vertical, -4}

      iex> five = Scenic.Scrollable.Direction.as_horizontal(5)
      ...> six = Scenic.Scrollable.Direction.as_vertical(6)
      ...> Scenic.Scrollable.Direction.subtract(five, six)
      {:horizontal, 5}

      iex> non_numeric_value = Scenic.Scrollable.Direction.as_horizontal(:non_numeric_value)
      ...> six = Scenic.Scrollable.Direction.as_vertical(6)
      ...> Scenic.Scrollable.Direction.subtract(non_numeric_value, six)
      {:horizontal, :non_numeric_value}
  """
  @spec subtract(t, t) :: t
  def subtract({:horizontal, x}, {:horizontal, y}) when is_number(x) and is_number(y),
    do: {:horizontal, x - y}

  def subtract({:vertical, x}, {:vertical, y}) when is_number(x) and is_number(y),
    do: {:vertical, x - y}

  def subtract({:horizontal, x}, _), do: {:horizontal, x}
  def subtract({:vertical, x}, _), do: {:vertical, x}

  @doc """
  Multiply two `t:Scenic.Scrollable.Direction.t/0` values. Only values associated with the same direction will be multiplied. Non numeric values are ignored.

  ## Examples

      iex> five = Scenic.Scrollable.Direction.as_horizontal(5)
      ...> six = Scenic.Scrollable.Direction.as_horizontal(6)
      ...> Scenic.Scrollable.Direction.multiply(five, six)
      {:horizontal, 30}

      iex> three = Scenic.Scrollable.Direction.as_vertical(3)
      ...> seven = Scenic.Scrollable.Direction.as_vertical(7)
      ...> Scenic.Scrollable.Direction.multiply(three, seven)
      {:vertical, 21}

      iex> five = Scenic.Scrollable.Direction.as_horizontal(5)
      ...> six = Scenic.Scrollable.Direction.as_vertical(6)
      ...> Scenic.Scrollable.Direction.multiply(five, six)
      {:horizontal, 5}

      iex> non_numeric_value = Scenic.Scrollable.Direction.as_horizontal(:non_numeric_value)
      ...> six = Scenic.Scrollable.Direction.as_vertical(6)
      ...> Scenic.Scrollable.Direction.multiply(non_numeric_value, six)
      {:horizontal, :non_numeric_value}
  """
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

  @doc """
  Divide two `t:Scenic.Scrollable.Direction.t/0` values. Only values associated with the same direction will be divided. Non numeric values are ignored.

  ## Examples

      iex> fifty = Scenic.Scrollable.Direction.as_horizontal(50)
      ...> ten = Scenic.Scrollable.Direction.as_horizontal(10)
      ...> Scenic.Scrollable.Direction.divide(fifty, ten)
      {:horizontal, 5.0}

      iex> nine = Scenic.Scrollable.Direction.as_vertical(9)
      ...> three = Scenic.Scrollable.Direction.as_vertical(3)
      ...> Scenic.Scrollable.Direction.divide(nine, three)
      {:vertical, 3.0}

      iex> six = Scenic.Scrollable.Direction.as_horizontal(6)
      ...> two = Scenic.Scrollable.Direction.as_vertical(2)
      ...> Scenic.Scrollable.Direction.divide(six, two)
      {:horizontal, 6}

      iex> non_numeric_value = Scenic.Scrollable.Direction.as_horizontal(:non_numeric_value)
      ...> six = Scenic.Scrollable.Direction.as_vertical(6)
      ...> Scenic.Scrollable.Direction.divide(non_numeric_value, six)
      {:horizontal, :non_numeric_value}
  """
  @spec divide(t, t) :: t
  def divide({:horizontal, x}, {:horizontal, y}) when is_number(x) and is_number(y),
    do: {:horizontal, x / y}

  def divide({:vertical, x}, {:vertical, y}) when is_number(x) and is_number(y),
    do: {:vertical, x / y}

  def divide({:horizontal, x}, _), do: {:horizontal, x}
  def divide({:vertical, x}, _), do: {:vertical, x}

  @doc """
  Apply a function only if the `t:Scenic.Scrollable.Direction.t\0` is associated with the horizontal direction.
  Returns a new `t:Scenic.Scrollable.Direction.t\0`.

  ## Examples

      iex> Scenic.Scrollable.Direction.map_horizontal({:horizontal, 5}, & &1 * 2)
      {:horizontal, 10}

      iex> Scenic.Scrollable.Direction.map_horizontal({:vertical, 5}, & &1 * 2)
      {:vertical, 5}
  """
  @spec map_horizontal(t, (term -> term)) :: t
  def map_horizontal({:horizontal, x}, fun), do: {:horizontal, fun.(x)}
  def map_horizontal(x, _), do: x

  @doc """
  Apply a function only if the `t:Scenic.Scrollable.Direction.t\0` is associated with the vertical direction.
  Returns a new `t:Scenic.Scrollable.Direction.t\0`.

  ## Examples

      iex> Scenic.Scrollable.Direction.map_vertical({:vertical, 5}, & &1 * 2)
      {:vertical, 10}

      iex> Scenic.Scrollable.Direction.map_vertical({:horizontal, 5}, & &1 * 2)
      {:horizontal, 5}
  """
  @spec map_vertical(t, (term -> term)) :: t
  def map_vertical({:vertical, x}, fun), do: {:vertical, fun.(x)}
  def map_vertical(x, _), do: x

  @doc """
  Apply a function to the `t:Scenic.Scrollable.Direction.t\0` inner value.
  Returns a new `t:Scenic.Scrollable.Direction.t\0`.

  ## Examples

      iex> Scenic.Scrollable.Direction.map({:horizontal, 5}, & &1 * 2)
      {:horizontal, 10}

      iex> Scenic.Scrollable.Direction.map({:vertical, 5}, & &1 * 2)
      {:vertical, 10}
  """
  @spec map(t, (term -> term)) :: t
  def map({direction, value}, fun), do: {direction, fun.(value)}
end
