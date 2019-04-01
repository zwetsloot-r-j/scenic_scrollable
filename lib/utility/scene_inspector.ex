defmodule Scenic.Scrollable.SceneInspector do
  alias Scenic.ViewPort.Tables
  @moduledoc false
  # This module is meant for testing and debugging purposes only

  defmacro __using__(opts) do
    quote do
      enabled = Enum.member?(unquote(opts)[:env] || [], Mix.env())

      if enabled do
        @doc false
        @spec inspect(pid) :: {:ok, {pid, term}} | {:error, :invalid_module}
        def inspect(pid) do
          module = __MODULE__

          case GenServer.call(pid, :inspect_state) do
            {pid, ^module, state} -> {:ok, {pid, state}}
            _ -> {:error, :invalid_module}
          end
        end

        @doc false
        @spec inspect() :: {:ok, {pid, term}} | {:error, atom}
        def inspect() do
          module = __MODULE__

          :ets.match(Tables.scenes_table(), {:_, {:"$1", :_, :_}})
          |> Enum.map(fn
            [pid] -> GenServer.call(pid, :inspect_state)
            _ -> {:error, :invalid_pid}
          end)
          |> Enum.map(fn
            {pid, ^module, state} -> {:ok, {pid, state}}
            _ -> {:error, :invalid_module}
          end)
          |> Enum.find(fn
            {:ok, _} -> true
            _ -> false
          end)
          |> (fn
                nil -> {:error, :scene_not_running}
                ok -> ok
              end).()
        end

        @doc false
        @spec inspect_until_found() :: {:ok, {pid, term}} | {:error, atom}
        def inspect_until_found() do
          case inspect() do
            {:ok, _} = ok ->
              ok

            {:error, :scene_not_running} ->
              Process.send_after(self(), :inspect_until_found, 100)

              receive do
                :inspect_until_found -> inspect_until_found()
                _ -> {:error, :unexpected_message}
              end

            error ->
              error
          end
        end

        @doc false
        @spec wait_until_destroyed(pid) :: :ok | {:error, atom}
        def wait_until_destroyed(pid) do
          :ets.match(Tables.scenes_table(), {:_, {:"$1", :_, :_}})
          |> Enum.find(fn
            [^pid] -> true
            _ -> false
          end)
          |> (fn
                nil ->
                  :ok

                _ ->
                  Process.send_after(self(), :wait_until_destroyed, 100)

                  receive do
                    :wait_until_destroyed -> wait_until_destroyed(pid)
                    _ -> {:error, :unexpected_message}
                  end
              end).()
        end

        @doc false
        @spec simulate_left_button_press(pid, Scenic.Math.vector_2(), atom) :: :ok
        def simulate_left_button_press(pid, position, origin_id) do
          simulate_input(pid, {:cursor_button, {:left, :press, 0, position}}, origin_id)
        end

        @doc false
        @spec simulate_left_button_release(pid, Scenic.Math.vector_2(), atom) :: :ok
        def simulate_left_button_release(pid, position, origin_id) do
          simulate_input(pid, {:cursor_button, {:left, :release, 0, position}}, origin_id)
        end

        @doc false
        @spec simulate_mouse_move(pid, Scenic.Math.vector_2(), atom) :: :ok
        def simulate_mouse_move(pid, position, origin_id) do
          simulate_input(pid, {:cursor_pos, position}, origin_id)
        end

        @doc false
        @spec simulate_mouse_exit(pid, atom) :: :ok
        def simulate_mouse_exit(pid, origin_id) do
          simulate_input(pid, {:cursor_exit, origin_id}, origin_id)
        end

        @doc false
        @spec simulate_key_press(pid, String.t(), atom) :: :ok
        def simulate_key_press(pid, key, origin_id) do
          simulate_input(pid, {:key, {key, :press, 0}}, origin_id)
        end

        @doc false
        @spec simulate_key_release(pid, String.t(), atom) :: :ok
        def simulate_key_release(pid, key, origin_id) do
          simulate_input(pid, {:key, {key, :press, 0}}, origin_id)
        end

        @doc false
        @spec simulate_input(pid, term, atom) :: :ok
        def simulate_input(pid, event, origin_id) do
          context = make_input_context(event, origin_id)
          GenServer.cast(pid, {:input, event, context})
        end

        @doc false
        @spec make_input_context(term, atom) :: Scenic.ViewPort.Context.t()
        defp make_input_context(event, origin_id) do
          viewport = get_viewport()

          Scenic.ViewPort.Context.build(%{
            viewport: viewport,
            graph_key: get_root_graph_key(viewport),
            uid: 0,
            id: origin_id,
            raw_input: event
          })
        end

        @doc false
        @spec get_viewport() :: pid | nil
        defp get_viewport() do
          GenServer.whereis(:main_viewport)
        end

        @doc false
        @spec get_root_graph_key(pid) :: term
        defp get_root_graph_key(viewport) do
          {:ok, %{root_graph: root}} = Scenic.ViewPort.info(viewport)
          root
        end

        @doc false
        def handle_call(:inspect_state, _from, state),
          do: {:reply, {self(), __MODULE__, state}, state}
      end
    end
  end
end
