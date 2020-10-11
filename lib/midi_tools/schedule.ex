defmodule MIDITools.Schedule do
  @moduledoc """
  Functions for using a MIDI schedule.
  """

  @typedoc """
  A list of tuples which indicate that the MIDI binary should play at the given time.
  """
  @type t :: [{non_neg_integer(), binary()}]

  @doc """
  Convert a list of events to MIDI schedule.
  See `MIDITools.Event` for creating these events.
  """
  @spec convert_events([MIDITools.Event.t()]) :: t()
  def convert_events(events) do
    events
    |> Enum.flat_map(&MIDITools.Event.convert/1)
    |> Enum.reduce(%{}, fn {time, midi}, acc ->
      Map.update(acc, time, midi, &<<&1::binary, midi::binary>>)
    end)
    |> Enum.sort()
  end
end
