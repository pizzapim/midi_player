defmodule MIDIPlayerTest do
  use ExUnit.Case
  doctest MIDIPlayer

  alias MIDIPlayer, as: Player

  setup do
    {:ok, _pid} = Player.start_link()
    :ok
  end

  setup_all do
    events = Enum.map(1..4, &MIDIPlayer.Event.Note.new(9, 51, &1 * 500, (&1 + 1) * 500, 127))
    duration = 2000
    [events: events, duration: duration]
  end

  test "play", %{events: events, duration: duration} do
    assert :ok = Player.generate_schedule(events, duration)
    assert :ok = Player.play()
    Process.sleep(2500)
  end

  test "pause & resume", %{events: events, duration: duration} do
    Player.generate_schedule(events, duration)
    Player.play()
    Process.sleep(1100)
    assert :ok = Player.pause()
    Process.sleep(500)
    assert :ok = Player.resume()
    Process.sleep(1400)
  end

  test "pause & resume edge cases", %{events: events, duration: duration} do
    Player.generate_schedule(events, duration)
    assert {:error, :not_started} = Player.pause()
    assert {:error, :not_paused} = Player.resume()
    Player.play()
    Player.pause()
    assert {:error, :already_paused} = Player.pause()
  end

  test "event conversion" do
    event1 = MIDIPlayer.Event.ChangeProgram.new(0, 1, 40)
    event2 = MIDIPlayer.Event.Note.new(0, 60, 1, 1000, 127)
    events = [event1, event2]
    duration = 100
    assert :ok = Player.generate_schedule(events, duration)

    change_program = MIDISynth.Command.change_program(0, 40)
    note_on = MIDISynth.Command.note_on(0, 60, 127)
    note_off = MIDISynth.Command.note_off(0, 60)

    [command1, command2] = Player.get_schedule()
    assert {1, <<^change_program::binary-size(2), ^note_on::binary-size(3)>>} = command1
    assert {1000, ^note_off} = command2
  end
end
