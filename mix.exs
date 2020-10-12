defmodule MIDIPlayer.MixProject do
  use Mix.Project

  def project do
    [
      app: :midi_player,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "MIDIPlayer",
      source_url: "https://github.com/pizzapim/midi_player",
      homepage_url: "https://github.com/pizzapim/midi_player",
      docs: [
        extras: ["README.md"],
        main: "readme"
      ],

      # Hex stuff
      description: description(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    """
    A MIDI player for Elixir.
    MIDIPlayer takes musical "events" like playing a note, converts them to MIDI commands, schedules them and then lets you play them.
    """
  end

  defp package do
    [
      name: "midi_player",
      licenses: ["GPL-3.0-or-later"],
      links: %{"GitHub" => "https://github.com/pizzapim/midi_player"}
    ]
  end

  defp deps do
    [
      {:midi_synth, "~> 0.4.0"},
      {:timex, "~> 3.6"},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false}
    ]
  end
end
