# MIDIPlayer

A MIDI player for Elixir.

## Prerequisites

Install FluidSynth to play MIDI commands:

On Linux:

```sh
sudo apt install libfluidsynth-dev
```

On OSX:

```sh
brew install fluidsynth
```

## Examples

First, let's create some events.
This plays a piano sound for the C note for 1 second:

```elixir
iex> piano = MIDIPlayer.Event.Note.new(0, 60, 0, 1000, 127)
```

We can change the instrument to a violin after one second like so:

```elixir
iex> change = MIDIPlayer.Event.ChangeProgram.new(0, 1000, 41)
```

(Note that it could be simpler to use another MIDI channel for another instrument.)

Finally, play two notes on the violin at the same time:

```elixir
iex> violin1 = MIDIPlayer.Event.Note.new(0, 67, 1000, 3000, 127)
iex> violin2 = MIDIPlayer.Event.Note.new(0, 64, 1000, 3000, 127)
```

Now we are ready to play these events.
First start the player like so:

```elixir
iex> MIDIPlayer.start_link()
```

Then load the events, and play them!

```elixir
iex> MIDIPlayer.generate_schedule([piano, change, violin1, violin2], 3000)
iex> MIDIPlayer.play()
```

## Thanks

This project uses [MIDISynth](https://github.com/fhunleth/midi_synth)
for generating MIDI commands and operating the FluidSynth synthesizer.
It also uses [Timex](https://github.com/bitwalker/timex)
for timing related functionality.
Inspiration from [Beats](https://github.com/mtrudel/beats).