defmodule Builder.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Deck.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Builder.DataCase
      @moduletag :tmp_dir
    end
  end

  setup tags do
    name = Ecto.UUID.generate() <> ".db"
    db = Path.join([tags[:tmp_dir], name])
    user_id = "user-" <> to_string(System.unique_integer([:positive]))
    # on_exit(fn ->
    #   File.rm!(db)
    #   File.rm!(db <> "-shm")
    #   File.rm!(db <> "-wal")
    # end)
    [database: db, user_id: user_id]
  end
end
