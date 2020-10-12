defmodule MIDIPlayer.EventTest do
  use ExUnit.Case
  doctest MIDIPlayer.Event

  alias MIDIPlayer.Event

  test "note event" do
    assert %Event.Note{channel: 0, tone: 60, start_time: 1, end_time: 1000, velocity: 127} =
             Event.Note.new(0, 60, 1, 1000, 127)
  end

  test "change program event" do
    assert %Event.ChangeProgram{channel: 0, time: 1, program: 40} =
             Event.ChangeProgram.new(0, 1, 40)
  end

  test "note event conversion" do
    note = Event.Note.new(0, 60, 1, 1000, 127)
    [note_on, note_off] = Event.convert(note)
    assert {1, <<0x90, 60, 127>>} = note_on
    assert {1000, <<0x80, 60, 64>>} = note_off
  end

  test "change program event conversion" do
    change_program = Event.ChangeProgram.new(0, 1, 40)
    assert [{1, <<0xC0, 40>>}] = Event.convert(change_program)
  end
end
