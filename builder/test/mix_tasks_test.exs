defmodule Builder.MixTasksTest do
  use Builder.DataCase
  alias Mix.Tasks.Engine.Generate
  alias Mix.Tasks.Engine.AddCard

  test "generate", %{database: database, user_id: user_id} do
    assert Generate.run(["--database", database, "--user-id", user_id])
  end

  test "add_card", %{database: database, user_id: user_id} do
    assert Generate.run(["--database", database, "--user-id", user_id])

    assert AddCard.run([
             "--database",
             database,
             "--asset",
             "test/fixtures/card/card.lua",
             "--asset",
             "test/fixtures/card/bg.png"
           ])
  end
end
