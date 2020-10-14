defmodule MIDIPlayer do
  use GenServer

  @moduledoc """
  A GenServer for playing a schedule of MIDI commands at predefined times.
  """

  # TBD: I think cancelling the timer could introduce a race condition.
  # Could maybe match timer's reference to saved one?

  @type schedule :: [{non_neg_integer(), binary()}]

  # Client API

  @doc """
  Start the MIDI player.

  Arguments are the same as `MIDISynth.start_link/2`.
  """
  @spec start_link(keyword(), GenServer.options()) :: GenServer.on_start()
  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  @doc """
  Generate the current schedule defined by the given events.

  The list of events is internally converted to MIDI commands.
  If multiple events are scheduled on the same time,
  then they are executed in the same order as in the list.
  The duration makes sure the player plays a (potential) pause after the last
  midi command.

  See `MIDIPlayer.Event` to create events.
  """
  @spec generate_schedule(GenServer.server(), [MIDIPlayer.Event.t()], non_neg_integer()) :: :ok
  def generate_schedule(player, events, duration) when duration > 0 do
    GenServer.call(player, {:generate_schedule, events, duration})
  end

  @doc """
  Play the current MIDI schedule from the start.
  """
  @spec play(GenServer.server()) :: :ok
  def play(player) do
    GenServer.call(player, :play)
  end

  @doc """
  Set the player on repeat or not.
  """
  @spec set_repeat(GenServer.server(), boolean()) :: :ok
  def set_repeat(player, repeat) when is_boolean(repeat) do
    GenServer.call(player, {:set_repeat, repeat})
  end

  @doc """
  Stop the player and cancel the pause.
  """
  @spec stop_playing(GenServer.server()) :: :ok
  def stop_playing(player) do
    GenServer.call(player, :stop_playing)
  end

  @doc """
  Pause the player.

  See `MIDIPlayer.resume/1` for resuming playback.
  """
  @spec pause(GenServer.server()) :: :ok | {:error, :already_paused | :not_started}
  def pause(player) do
    GenServer.call(player, :pause)
  end

  @doc """
  Resume playback on the player after it has been paused.
  """
  @spec resume(GenServer.server()) :: :ok | {:error, :not_paused}
  def resume(player) do
    GenServer.call(player, :resume)
  end

  @doc """
  Get the current schedule of the player.

  The schedule is a list of tuples of a time in milliseconds and the
  corresponding bitstream of MIDI commands to be played at that time.
  The list is guaranteed to be ascending in time.
  """
  @spec get_schedule(GenServer.server()) :: schedule()
  def get_schedule(player) do
    GenServer.call(player, :get_schedule)
  end

  # Server callbacks

  @impl GenServer
  def init(args) do
    {:ok, synth} = MIDISynth.start_link(args)

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

  @impl GenServer
  def handle_call({:generate_schedule, events, duration}, _from, state) do
    state = %{state | schedule: convert_events(events)}
    {:reply, :ok, %{reset(state) | duration: duration}}
  end

  def handle_call(:play, _from, %{schedule: schedule} = state) do
    start_time = Timex.now()
    timer = start_timer(schedule, start_time)

    {:reply, :ok, %{reset(state) | timer: timer, start_time: start_time}}
  end

  def handle_call({:set_repeat, repeat}, _from, state) do
    {:reply, :ok, %{state | repeat: repeat}}
  end

  def handle_call(:stop_playing, _from, state) do
    {:reply, :ok, reset(state)}
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

  def handle_call(:get_schedule, _from, %{schedule: schedule} = state) do
    {:reply, schedule, state}
  end

  @impl GenServer
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

  defp convert_events(events) do
    events
    |> Enum.flat_map(&MIDIPlayer.Event.convert/1)
    |> Enum.reduce(%{}, fn {time, midi}, acc ->
      Map.update(acc, time, midi, &<<&1::binary, midi::binary>>)
    end)
    |> Enum.sort()
  end

  defp reset(%{timer: timer, schedule: schedule} = state) do
    if timer != nil do
      Process.cancel_timer(timer, info: false)
    end

    %{state | timer: nil, pause_time: nil, schedule_left: schedule}
  end
end
