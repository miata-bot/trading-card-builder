defmodule Mix.Tasks.Engine.AddCard do
  use Mix.Task

  alias Deck.Manager

  def run(args) do
    Application.ensure_all_started(:ecto)

    {parsed, _, _} =
      OptionParser.parse(args,
        strict: [
          database: :string,
          asset: [:keep, :string]
        ]
      )

    {database_file, assets} = Keyword.pop!(parsed, :database)

    {:ok, result} = Manager.create_card(database_file, assets)

    Mix.shell().info("""
    Card created with #{Enum.count(result.blocks)} blocks
    id=#{result.card.id}
    """)
  end
end
