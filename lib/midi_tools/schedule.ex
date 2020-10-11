defmodule MIDITools.Schedule do
  def convert_events(events) do
    events
    |> Enum.flat_map(&MIDITools.Event.convert/1)
    |> Enum.reduce(%{}, fn {time, midi}, acc ->
      Map.update(acc, time, midi, &<<&1::binary, midi::binary>>)
    end)
    |> Enum.sort()
  end
end
