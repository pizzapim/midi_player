defmodule MIDITools.Player do
  use GenServer

  # Client API

  def start_link(arg \\ nil) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def set_schedule(schedule, duration) do
    GenServer.call(__MODULE__, {:set_schedule, schedule, duration})
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

  def pause do
    GenServer.call(__MODULE__, :pause)
  end

  def resume do
    GenServer.call(__MODULE__, :resume)
  end

  # Server callbacks

  @impl true
  def init(_arg) do
    {:ok, synth} = MIDISynth.start_link([])

    {:ok,
     %{
       timer: nil,
       schedule: [],
       schedule_left: [],
       start_time: nil,
       duration: 0,
       synth: synth,
       repeat: false,
       pause_time: nil
     }}
  end

  @impl true
  def handle_call({:set_schedule, schedule, duration}, _from, state) do
    {:reply, :ok, %{state | schedule: schedule, schedule_left: schedule, duration: duration}}
  end

  def handle_call(:play, _from, %{timer: timer, schedule: schedule} = state) do
    if timer != nil do
      Process.cancel_timer(timer, info: false)
    end

    start_time = Timex.now()
    timer = start_timer(schedule, start_time)

    {:reply, :ok,
     %{state | timer: timer, start_time: start_time, schedule_left: schedule, pause_time: nil}}
  end

  def handle_call({:set_repeat, repeat}, _from, state) do
    {:reply, :ok, %{state | repeat: repeat}}
  end

  def handle_call(:stop_playing, _from, %{timer: timer} = state) do
    if timer != nil do
      Process.cancel_timer(timer, info: false)
    end

    {:reply, :ok, %{state | timer: nil, pause_time: nil}}
  end

  def handle_call(:pause, _from, %{pause_time: pause_time} = state) when pause_time != nil do
    {:reply, {:error, :already_paused}, state}
  end

  def handle_call(:pause, _from, %{timer: nil} = state) do
    {:reply, {:error, :not_started}, state}
  end

  def handle_call(:pause, _from, %{timer: timer} = state) do
    Process.cancel_timer(timer, info: false)
    pause_time = Timex.now()

    {:reply, :ok, %{state | timer: nil, pause_time: pause_time}}
  end

  def handle_call(:resume, _from, %{pause_time: nil} = state) do
    {:reply, {:error, :not_paused}, state}
  end

  def handle_call(
        :resume,
        _from,
        %{start_time: start_time, pause_time: pause_time, schedule_left: schedule_left} = state
      ) do
    time_since_pause = Timex.diff(Timex.now(), pause_time, :millisecond)
    start_time = DateTime.add(start_time, time_since_pause, :millisecond)
    timer = start_timer(schedule_left, start_time)

    {:reply, :ok, %{state | timer: timer, start_time: start_time, pause_time: nil}}
  end

  @impl true
  def handle_info(
        :play,
        %{
          schedule_left: schedule_left,
          start_time: start_time,
          synth: synth,
          duration: duration
        } = state
      ) do
    {timer, schedule_left} = play_next_command(schedule_left, start_time, duration, synth)
    {:noreply, %{state | timer: timer, schedule_left: schedule_left}}
  end

  def handle_info(
        :end,
        %{repeat: true, start_time: start_time, duration: duration, schedule: schedule} = state
      ) do
    start_time = DateTime.add(start_time, duration, :millisecond)
    timer = start_timer(schedule, start_time)
    {:noreply, %{state | start_time: start_time, timer: timer, schedule_left: schedule}}
  end

  def handle_info(:end, state) do
    {:noreply, %{state | timer: nil}}
  end

  # Private functions

  defp start_timer([], _start_time), do: nil

  defp start_timer([{offset, _command} | _], start_time) do
    next_time = DateTime.add(start_time, offset, :millisecond)
    delay = max(Timex.diff(next_time, Timex.now(), :millisecond), 0)
    Process.send_after(self(), :play, delay)
  end

  defp play_next_command([], start_time, duration, _synth) do
    end_time = DateTime.add(start_time, duration, :millisecond)
    delay = max(Timex.diff(end_time, Timex.now(), :millisecond), 0)
    timer = Process.send_after(self(), :end, delay)
    {timer, []}
  end

  defp play_next_command(
         [{offset, command} | next_schedule] = schedule_left,
         start_time,
         duration,
         synth
       ) do
    next_time = DateTime.add(start_time, offset, :millisecond)
    micro_diff = Timex.diff(next_time, Timex.now(), :microsecond)

    if micro_diff < 500 do
      # Play command, and try to play next command too.
      MIDISynth.midi(synth, command)
      play_next_command(next_schedule, start_time, duration, synth)
    else
      # Command is too far in the future, schedule next timer.
      delay = max(ceil(micro_diff / 1000), 0)
      timer = Process.send_after(self(), :play, delay)
      {timer, schedule_left}
    end
  end
end
