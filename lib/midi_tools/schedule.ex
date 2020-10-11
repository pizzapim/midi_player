defmodule MIDITools.Schedule do
  def convert_events(events) do
    events
    |> Enum.flat_map(&MIDITools.Event.convert/1)
    |> Enum.reduce(%{}, fn {time, midi}, acc ->
      Map.update(acc, time, midi, &<<midi::binary, &1::binary>>)
    end)
    |> Enum.sort()
  end
end
