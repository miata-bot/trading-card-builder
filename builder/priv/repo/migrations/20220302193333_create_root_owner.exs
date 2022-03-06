defmodule Deck.Repo.Migrations.CreateRootOwner do
  use Ecto.Migration

  def change do
    create table(:root_owner, primary_key: false) do
      add :id, :tinyint, null: false, default: 0, primary_key: true
      add :owner_id, references(:owners), null: false
      add :private_key, :binary, null: false
    end

    owner_discord_id = System.fetch_env!("ENGINE_USER_ID")
    owner_private_key = X509.PrivateKey.new_rsa(2048)
    owner_public_key = X509.PublicKey.derive(owner_private_key)

    owner_private_key = X509.PrivateKey.to_der(owner_private_key)
    owner_public_key = X509.PublicKey.to_der(owner_public_key)

    execute fn ->
      repo().query!("""
      INSERT INTO owners(id, discord_user_id, public_key) VALUES($1, $2, $3);
      """, [Ecto.UUID.autogenerate(), owner_discord_id, owner_public_key], [log: false])
    end

    execute fn ->
      repo().query!("""
      CREATE TRIGGER root_owner_no_insert
      BEFORE INSERT ON root_owner
      WHEN (SELECT COUNT(*) FROM root_owner) >= 1   -- limit here
      BEGIN
        SELECT RAISE(FAIL, 'Only One Root Owner may exist');
      END;
      """, [], [log: false])
    end

    execute fn ->
      %{rows: [[id]]} = repo().query!("""
      SELECT id FROM 'owners';
      """, [], [log: false])

      repo().query!("""
      INSERT INTO root_owner(owner_id, private_key) VALUES($1, $2);
      """, [id, owner_private_key], [log: false])
    end
  end
end
