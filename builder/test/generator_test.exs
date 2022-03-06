defmodule Builder.GeneratorTest do
  use Builder.DataCase
  alias Deck.{Repo, Generator, RootOwner, Owner}

  test "initializes a database", %{database: database, user_id: user_id} do
    assert :ok = Generator.generate(database: database, user_id: user_id)
    assert Repo.with_repo([database: database], fn _ -> Repo.one!(Owner) end)
    assert Repo.with_repo([database: database], fn _ -> Repo.one!(RootOwner) end)
  end

  test "only root owner", %{database: database, user_id: user_id} do
    assert :ok = Generator.generate(database: database, user_id: user_id)
    owner = Repo.with_repo([database: database], fn _ -> Repo.one!(Owner) end)

    assert_raise Exqlite.Error, fn ->
      Repo.with_repo([database: database], fn _ ->
        Repo.insert!(%RootOwner{
          private_key: "fake",
          owner_id: owner.id
        })
      end)
    end
  end

  test "owner pub/priv key", %{database: database, user_id: user_id} do
    assert :ok = Generator.generate(database: database, user_id: user_id)
    owner = Repo.with_repo([database: database], fn _ -> Repo.one!(Owner) end)
    root_owner = Repo.with_repo([database: database], fn _ -> Repo.one!(RootOwner) end)

    {:ok, priv_key} = X509.PrivateKey.from_der(root_owner.private_key)
    {:ok, pub_key} = X509.PublicKey.from_der(owner.public_key)

    plaintext = "Hello, world!"
    ciphertext = :public_key.encrypt_public(plaintext, pub_key)
    assert ^plaintext = :public_key.decrypt_private(ciphertext, priv_key)
  end
end
