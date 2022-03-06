defmodule Builder.ManagerTest do
  use Builder.DataCase
  alias Deck.{Repo, Manager, Generator, RootOwner, Owner}

  test "adds a card", %{database: database, user_id: user_id} do
    assert :ok = Generator.generate(database: database, user_id: user_id)
    owner = Repo.with_repo([database: database], fn _ -> Repo.one!(Owner) end)

    assets = [{:asset, "test/fixtures/card/card.lua"}]
    assert {:ok, result} = Manager.create_card(database, assets)

    assert Enum.count(result.blocks) == Enum.count(assets)
    assert result.owner.id == owner.id
    assert result.card
  end
end
