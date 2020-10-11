defmodule MIDITools.Event do
  @moduledoc """
  Several musical events which can be converted to MIDI commands.
  All timings are in milliseconds.
  """

  defmodule Note do
    @moduledoc """
    An event which plays the given tone for the given timespan.
    """

    defstruct channel: 0, tone: 0, start_time: 0, end_time: 0, velocity: 0

    @spec new(MIDISynth.Command.channel(), non_neg_integer(), non_neg_integer(), non_neg_integer(), MIDISynth.Command.velocity()) :: %Note{}
    def new(channel, tone, start_time, end_time, velocity) when start_time >= 0 and end_time > start_time do
      %__MODULE__{
        channel: channel,
        tone: tone,
        start_time: start_time,
        end_time: end_time,
        velocity: velocity
      }
    end
  end

  defmodule ChangeProgram do
    @moduledoc """
    An event which changes the current program of the given channel.
    """

    defstruct channel: 0, time: 0, program: 0

    @spec new(MIDISynth.Command.channel(), non_neg_integer(), non_neg_integer()) :: %ChangeProgram{}
    def new(channel, time, program) do
      %__MODULE__{channel: channel, time: time, program: program}
    end
  end

  @typedoc """
  A musical event.
  """
  @type t :: %Note{} | %ChangeProgram{}

  @doc """
  Converts the event to a list of MIDI commands.
  """
  @spec convert(t()) :: MIDITools.Schedule.t()
  def convert(%Note{
        channel: channel,
        tone: tone,
        start_time: start_time,
        end_time: end_time,
        velocity: velocity
      }) do
    note_on = MIDISynth.Command.note_on(channel, tone, velocity)
    note_off = MIDISynth.Command.note_off(channel, tone)
    [{start_time, note_on}, {end_time, note_off}]
  end

  def convert(%ChangeProgram{channel: channel, time: time, program: program}) do
    change_program = MIDISynth.Command.change_program(channel, program)

    [{time, change_program}]
  end
end
