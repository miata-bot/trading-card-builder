defmodule Deck.Manager do
  alias Deck.{
    Repo,
    Owner,
    Card,
    CardBlock
  }

  alias Ecto.Multi

  @doc """

  """
  def create_card(database, assets) do
    Repo.with_repo([database: database], fn _ ->
      Multi.new()
      |> Multi.run(:owner, &get_owner/2)
      |> Multi.run(:uninitialized_card, &new_card/2)
      |> Multi.run(:blocks, &add_blocks(&1, &2, assets))
      |> Multi.run(:card, &card_update_with_blocks/2)
      |> Repo.transaction()
    end)
  end

  @spec hash(binary()) :: binary()
  defp hash(data) do
    :crypto.hash(:sha256, data)
    |> Base.encode16(case: :upper)
  end

  @spec get_owner(Ecto.Repo.t(), any) :: {:ok, Owner.t()}
  defp get_owner(repo, _) do
    creator = repo.one!(Owner)
    {:ok, creator}
  end

  @spec new_card(Ecto.Repo.t(), %{owner: Owner.t()}) ::
          {:ok, Card.t()} | {:error, Ecto.Changeset.t()}
  defp new_card(repo, %{owner: owner}) do
    repo.insert(%Card{
      creator_id: owner.id,
      hash: hash(<<>>)
    })
  end

  @spec add_blocks(Ecto.Repo.t(), %{uninitialized_card: Card.t()}, [{:asset, Path.t()}]) ::
          {:ok, [CardBlock.t()]}
  defp add_blocks(repo, %{uninitialized_card: card}, assets) do
    blocks =
      for {:asset, asset} <- assets do
        name = Path.basename(asset)
        data = File.read!(asset)
        repo.insert!(%CardBlock{card_id: card.id, data: data, name: name})
      end

    {:ok, blocks}
  end

  @spec card_update_with_blocks(Ecto.Repo.t(), %{
          uninitialized_card: Card.t(),
          blocks: [CardBlock.t()]
        }) ::
          {:ok, Card.t()} | {:error, Ecto.Changeset.t()}
  defp card_update_with_blocks(repo, %{uninitialized_card: card, blocks: blocks}) do
    block_data =
      Enum.reduce(blocks, <<>>, fn %{data: data}, acc ->
        acc <> data
      end)

    Ecto.Changeset.change(card, %{hash: hash(block_data)})
    |> repo.update()
  end
end
