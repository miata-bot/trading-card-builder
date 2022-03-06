defmodule Mix.Tasks.Engine.Generate do
  use Mix.Task

  def run(args) do
    Application.ensure_all_started(:ecto)

    {parsed, _, _} =
      OptionParser.parse(args,
        strict: [
          user_id: :string,
          database: :string
        ]
      )

    Deck.Generator.generate(parsed)
    Mix.shell().info("Generated new databae: #{parsed[:database]}")
  end
end
