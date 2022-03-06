defmodule Deck.Repo.Migrations.CreateCards do
  use Ecto.Migration

  def change do
    create table(:cards) do
      add :creator_id, references(:owners), null: false
      add :hash, :string, null: false
    end

    create table(:card_blocks) do
      add :card_id, references(:cards), null: false
      add :name, :string, null: false
      add :data, :binary, null: false
    end
  end
end
