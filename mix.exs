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
        main: "MIDIPlayer"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
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
