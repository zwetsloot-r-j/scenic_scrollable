defmodule Scenic.Scrollable.Acceleration do
  @moduledoc """
  Module for calculating the scroll speed for `Scenic.Scrollable` components.
  """

  alias Scenic.Math.Vector2

  @typedoc """
  Shorthand for `t:Scenic.Math.vector_2/0`.
  Consists of a tuple containing the x and y numeric values.
  """
  @type v2 :: Scenic.Math.vector_2()

  @typedoc """
  Data structure containing settings that define the behaviour of the `Scenic.Scrollable` components scroll speed and acceleration. Note that the `Scenic.Scrollable` content may not be able to move when the acceleration is set too low, or the mass and counter_pressure are set too high.

  Default settings:
  - acceleration: 20
  - mass: 1
  - counter_pressure: 0.1
  """
  @type settings :: %{
          optional(:acceleration) => number,
          optional(:mass) => number,
          optional(:counter_pressure) => number
        }

  @typedoc """
  Data structure with the necessary values to calculate the current scroll speed.
  """
  @type t :: %{
          acceleration: number,
          mass: number,
          counter_pressure: number,
          force: v2,
          speed: v2
        }

  defstruct acceleration: 20,
            mass: 1,
            counter_pressure: 0.1,
            force: {0, 0},
            speed: {0, 0}

  # Value with which to multiply a speed value, to convert it to the distance it would travel during one frame.
  @speed_to_distance_factor 0.1

  @doc """
  Initializes a `t:Scenic.Scrollable.Acceleration.t` state object based on the passed `t:Scenic.Scrollable.Acceleration.settings/0`.
  When nil is passed, the default settings will be used.
  """
  @spec init(settings) :: t
  def init(nil), do: %__MODULE__{}

  def init(settings) do
    Enum.reduce(settings, %__MODULE__{}, fn {key, value}, state ->
      Map.put(state, key, value)
    end)
  end

  @doc """
  Find out if the `Scenic.Scrollable` component is currently stationary.
  """
  @spec is_stationary?(t) :: boolean
  def is_stationary?(%{speed: {0, 0}}), do: true

  def is_stationary?(_), do: false

  @doc """
  Apply force in the specified direction to make the `Scenic.Scrollable` component move.
  """
  @spec apply_force(t, v2) :: t
  def apply_force(state, force) do
    Map.update(state, :speed, {0, 0}, fn speed ->
      Vector2.mul(force, state.acceleration)
      |> Vector2.div(state.mass)
      |> Vector2.add(speed)
    end)
  end

  @doc """
  Directly update the speed of the `Scenic.Scrollable` components scroll movement, to make it move at a certain velocity in the given direction.
  """
  @spec set_speed(t, v2) :: t
  def set_speed(state, speed) do
    %{state | speed: speed}
  end

  @doc """
  Apply counter pressure to the current `Scenic.Scrollable` comonents movement.
  The counter pressures strength is calculated based on the `Scenic.Scrollable` components current speed, the components mass set during initialization, and the counter pressure value set during initialization.
  """
  @spec apply_counter_pressure(t) :: t
  def apply_counter_pressure(state) do
    Map.update(state, :speed, {0, 0}, fn speed ->
      Vector2.invert(speed)
      |> Vector2.mul(state.counter_pressure)
      |> Vector2.mul(state.mass)
      |> Vector2.add(speed)
      |> Vector2.trunc()
    end)
  end

  @doc """
  Calculate the translation of a point based on the current speed.
  """
  @spec translate(t, v2) :: v2
  def translate(%{speed: speed}, position) do
    Vector2.mul(speed, @speed_to_distance_factor)
    |> Vector2.add(position)
  end
end
