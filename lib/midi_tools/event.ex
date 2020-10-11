defmodule MIDITools.Event do
  defmodule Note do
    defstruct channel: 0, tone: 0, start_time: 0, end_time: 0, velocity: 0

    def new(channel, tone, start_time, end_time, velocity) do
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
    defstruct channel: 0, time: 0, program: 0

    def new(channel, time, program) do
      %__MODULE__{channel: channel, time: time, program: program}
    end
  end

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
