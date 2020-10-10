defmodule MIDITools.Player do
  use GenServer

  # Client API

  def start_link(arg \\ nil) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def set_schedule(schedule, end_time) do
    GenServer.call(__MODULE__, {:set_schedule, schedule, end_time})
  end

  def play do
    GenServer.call(__MODULE__, :play)
  end

  def set_repeat(repeat) do
    GenServer.call(__MODULE__, {:set_repeat, repeat})
  end

  def stop_playing do
    GenServer.call(__MODULE__, :stop_playing)
  end

  # Server callbacks

  @impl true
  def init(_arg) do
    {:ok, synth} = MIDISynth.start_link([])
    epoch = Timex.epoch() |> Timex.to_datetime()

    {:ok,
     %{
       timer: nil,
       schedule: [],
       schedule_left: [],
       start_time: epoch,
       end_time: 0,
       synth: synth,
       repeat: false
     }}
  end

  @impl true
  def handle_call({:set_schedule, schedule, end_time}, _from, state) do
    {:reply, :ok, %{state | schedule: schedule, schedule_left: schedule, end_time: end_time}}
  end

  def handle_call(:play, _from, %{timer: timer} = state) when timer != nil do
    {:reply, :already_started, state}
  end

  def handle_call(:play, _from, %{schedule: schedule} = state) do
    start_time = Timex.now()
    timer = start_timer(schedule, start_time)
    {:reply, :ok, %{state | timer: timer, start_time: start_time, schedule_left: schedule}}
  end

  def handle_call({:set_repeat, repeat}, _from, state) do
    {:reply, :ok, %{state | repeat: repeat}}
  end

  def handle_call(:stop_playing, _from, %{timer: timer} = state) do
    Process.cancel_timer(timer, info: false)
    {:reply, :ok, %{state | timer: nil}}
  end

  @impl true
  def handle_info(
        :play,
        %{
          schedule_left: schedule_left,
          start_time: start_time,
          synth: synth,
          repeat: repeat,
          end_time: end_time,
          schedule: schedule
        } = state
      ) do
    {timer, schedule_left} = play_next_command(schedule_left, start_time, synth)
    state = %{state | timer: timer, schedule_left: schedule_left}

    if repeat and schedule_left == [] do
      start_time = DateTime.add(start_time, end_time, :millisecond)
      timer = start_timer(schedule, start_time)
      {:noreply, %{state | start_time: start_time, timer: timer, schedule_left: schedule}}
    else
      {:noreply, state}
    end
  end

  # Private functions

  defp start_timer([], _start_time), do: nil

  defp start_timer([{offset, _command} | _], start_time) do
    next_time = DateTime.add(start_time, offset, :millisecond)
    delay = max(Timex.diff(next_time, Timex.now(), :millisecond), 0)
    Process.send_after(self(), :play, delay)
  end

  defp play_next_command([], _start_time, _synth), do: {nil, []}

  defp play_next_command([{offset, command} | next_schedule] = schedule_left, start_time, synth) do
    next_time = DateTime.add(start_time, offset, :millisecond)
    micro_diff = Timex.diff(next_time, Timex.now(), :microsecond)

    if micro_diff < 500 do
      # Play command, and try to play next command too.
      MIDISynth.midi(synth, command)
      play_next_command(next_schedule, start_time, synth)
    else
      # Command is too far in the future, schedule next timer.
      delay = max(ceil(micro_diff / 1000), 0)
      timer = Process.send_after(self(), :play, delay)
      {timer, schedule_left}
    end
  end
end
