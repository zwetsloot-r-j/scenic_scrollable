defmodule Scenic.Scrollable.Acceleration do
  alias Scenic.Math.Vector2

  @type v2 :: Scenic.Math.vector_2()

  @type t :: %{
          acceleration: number,
          mass: number,
          counter_pressure: number,
          speed: v2
        }

  defstruct acceleration: 10,
            mass: 1,
            counter_pressure: 0.1,
            force: {0, 0},
            speed: {0, 0}

  @speed_to_distance_factor 0.1
  # speed = speed + force / mass
  # counter_pressure_force = -speed * counter_pressure * mass

  def init(nil), do: %__MODULE__{}

  def init(acceleration_settings) do
    Enum.reduce(acceleration_settings, %__MODULE__{}, fn {key, value}, state ->
      Map.put(state, key, value)
    end)
  end

  def is_stationary?(%{speed: {0, 0}}), do: true

  def is_stationary?(_), do: false

  def apply_force(state, force) do
    # IO.inspect(state, label: "before")
    Map.update(state, :speed, {0, 0}, fn speed ->
      Vector2.mul(force, state.acceleration)
      |> Vector2.div(state.mass)
      |> Vector2.add(speed)
    end)

    # |> IO.inspect(label: "after")
  end

  def set_speed(state, speed) do
    %{state | speed: speed}
  end

  def apply_counter_pressure(state) do
    Map.update(state, :speed, {0, 0}, fn speed ->
      Vector2.invert(speed)
      |> Vector2.mul(state.counter_pressure)
      |> Vector2.mul(state.mass)
      |> Vector2.add(speed)
      |> Vector2.trunc()
    end)
  end

  def translate(%{speed: speed}, position) do
    Vector2.mul(speed, @speed_to_distance_factor)
    |> Vector2.add(position)
  end
end
