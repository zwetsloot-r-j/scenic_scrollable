defmodule Scenic.Scrollable.AccelerationTest do
  use ExUnit.Case
  doctest Scenic.Scrollable.Acceleration
  alias Scenic.Scrollable.Acceleration

  setup_all context do
    {:ok, Map.put(context, :default, %Acceleration{})}
  end

  test "init", %{default: default} do
    state = Acceleration.init(nil)
    assert state == default

    state = Acceleration.init(%{acceleration: 18})
    assert state == %{default | acceleration: 18}

    state = Acceleration.init(%{mass: 2})
    assert state == %{default | mass: 2}

    state = Acceleration.init(%{counter_pressure: 0.2})
    assert state == %{default | counter_pressure: 0.2}
  end

  test "is_stationary?", %{default: default} do
    assert Acceleration.is_stationary?(default) == true
    assert Acceleration.is_stationary?(%{default | speed: {1, 0}}) == false
    assert Acceleration.is_stationary?(%{default | speed: {0, 1}}) == false
    assert Acceleration.is_stationary?(%{default | speed: {1, 1}}) == false
    assert Acceleration.is_stationary?(%{default | speed: {1.0, 1.0}}) == false
    assert Acceleration.is_stationary?(%{default | speed: {0.000001, 0}}) == false
  end

  test "apply_force", %{default: default} do
    state = Acceleration.apply_force(default, {2, 0})
    assert state.speed == {40.0, 0.0}

    state = Acceleration.apply_force(%{default | speed: {0, 5}}, {0, 1})
    assert state.speed == {0.0, 25.0}

    state = Acceleration.apply_force(%{default | mass: 2}, {2.0, 0.0})
    assert state.speed == {20.0, 0.0}
  end

  test "set_speed", %{default: default} do
    state = Acceleration.set_speed(default, {3, 0})
    assert state.speed == {3, 0}

    state = Acceleration.set_speed(default, {0.0, 8.0})
    assert state.speed == {0.0, 8.0}
  end

  test "apply_counter_pressure", %{default: default} do
    state = Acceleration.apply_counter_pressure(default)
    assert state.speed == {0, 0}

    state = Acceleration.apply_counter_pressure(%{default | speed: {10, 10}})
    assert state.speed == {9, 9}

    state =
      Acceleration.apply_counter_pressure(%{default | speed: {10, 10}, counter_pressure: 0.2})

    assert state.speed == {8, 8}

    state = Acceleration.apply_counter_pressure(%{default | speed: {10, 10}, mass: 2})
    assert state.speed == {8, 8}
  end

  test "translate", %{default: default} do
    position = Acceleration.translate(%{default | speed: {10, 10}}, {5, 1})
    assert position == {6, 2}

    position = Acceleration.translate(%{default | speed: {1, -1.0}}, {-2.0, -3.5})
    assert position == {-1.9, -3.6}
  end
end
