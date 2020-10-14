defmodule MIDIPlayerTest do
  use ExUnit.Case
  doctest MIDIPlayer

  alias MIDIPlayer, as: Player
  alias MIDIPlayer.Event

  setup do
    {:ok, player} = Player.start_link([])
    [player: player]
  end

  setup_all do
    events = Enum.map(1..4, &Event.note(9, 51, &1 * 500, (&1 + 1) * 500, 127))
    duration = 2000
    [events: events, duration: duration]
  end

  test "play", %{player: player, events: events, duration: duration} do
    assert :ok = Player.generate_schedule(player, events, duration)
    assert :ok = Player.play(player)
    Process.sleep(2500)
  end

  test "pause & resume", %{player: player, events: events, duration: duration} do
    Player.generate_schedule(player, events, duration)
    Player.play(player)
    Process.sleep(1100)
    assert :ok = Player.pause(player)
    Process.sleep(500)
    assert :ok = Player.resume(player)
    Process.sleep(1400)
  end

  test "pause & resume edge cases", %{player: player, events: events, duration: duration} do
    Player.generate_schedule(player, events, duration)
    assert {:error, :not_started} = Player.pause(player)
    assert {:error, :not_paused} = Player.resume(player)
    Player.play(player)
    Player.pause(player)
    assert {:error, :already_paused} = Player.pause(player)
  end

  test "event conversion", %{player: player} do
    event1 = Event.change_program(0, 1, 40)
    event2 = Event.note(0, 60, 1, 1000, 127)
    events = [event1, event2]
    duration = 100
    assert :ok = Player.generate_schedule(player, events, duration)

    change_program = MIDISynth.Command.change_program(0, 40)
    note_on = MIDISynth.Command.note_on(0, 60, 127)
    note_off = MIDISynth.Command.note_off(0, 60)

    [command1, command2] = Player.get_schedule(player)
    assert {1, <<^change_program::binary-size(2), ^note_on::binary-size(3)>>} = command1
    assert {1000, ^note_off} = command2
  end
end
