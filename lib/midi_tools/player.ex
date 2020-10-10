defmodule Player do
  use GenServer

  # Client API

  def start_link(arg \\ nil) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def set_schedule(schedule) do
    GenServer.call(__MODULE__, {:set_schedule, schedule})
  end

  def play do
    GenServer.call(__MODULE__, :play)
  end

  # Server callbacks

  @impl true
  def init(_arg) do
    {:ok, synth} = MIDISynth.start_link([])
    epoch = Timex.epoch() |> Timex.to_datetime()
    {:ok, %{timer: nil, schedule: [], schedule_left: [], start_time: epoch, synth: synth}}
  end

  @impl true
  def handle_call({:set_schedule, schedule}, _from, state) do
    {:reply, :ok, %{state | schedule: schedule, schedule_left: schedule}}
  end

  def handle_call(:play, _from, %{schedule_left: schedule_left} = state) do
    start_time = Timex.now()
    state = %{state | start_time: start_time}
    timer = start_timer(schedule_left, start_time)
    {:reply, :ok, %{state | timer: timer}}
  end

  @impl true
  def handle_info(
        :play,
        %{schedule_left: schedule_left, start_time: start_time, synth: synth} = state
      ) do
    schedule_left = play_next_midi(schedule_left, start_time, synth)
    {:noreply, %{state | schedule_left: schedule_left}}
  end

  defp play_next_midi([], _start_time, _synth), do: []

  defp play_next_midi([{offset, command} | next_schedule] = schedule_left, start_time, synth) do
    next_time = DateTime.add(start_time, offset, :millisecond)
    micro_diff = Timex.diff(next_time, Timex.now(), :microsecond)

    if micro_diff < 500 do
      # Play command, and try to play next command too.
      MIDISynth.midi(synth, command)
      play_next_midi(next_schedule, start_time, synth)
    else
      # Command is too far in the future, schedule next timer.
      delay = ceil(micro_diff / 1000)
      Process.send_after(self(), :play, delay)
      schedule_left
    end
  end

  defp start_timer([], _start_time), do: nil

  defp start_timer([{offset, _command} | _], start_time) do
    next_time = DateTime.add(start_time, offset, :millisecond)
    delay = Timex.diff(next_time, Timex.now(), :millisecond)
    Process.send_after(self(), :play, delay)
  end
end
