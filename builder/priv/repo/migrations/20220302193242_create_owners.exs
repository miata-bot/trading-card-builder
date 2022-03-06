defmodule Deck.Repo.Migrations.CreateOwners do
  use Ecto.Migration

  def change do
    create table(:owners) do
      add :public_key, :binary, null: false
      add :discord_user_id, :binary
    end

    create unique_index(:owners, :public_key)
    create unique_index(:owners, :discord_user_id)
    create unique_index(:owners, [:public_key, :discord_user_id])
  end
end
