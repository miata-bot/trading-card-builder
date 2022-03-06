defmodule Deck.Generator do
  alias Deck.Repo

  @moduledoc """
  Generates a new empty database

  Required opts:

  * `database` - path to the database to generate.
  * `user_id` - discord user id snowflake
  """
  def generate(opts) do
    database_file = Keyword.fetch!(opts, :database)
    if File.exists?(database_file), do: File.rm!(database_file)
    System.put_env("ENGINE_USER_ID", Keyword.fetch!(opts, :user_id))

    Repo.with_repo(opts, fn %{pid: pid} ->
      migrate(
        all: true,
        dynamic_repo: pid,
        log: false
      )
    end)

    System.delete_env("ENGINE_USER_ID")
    :ok
  end

  @doc false
  def migrate(config) do
    {:ok, _, _} = Ecto.Migrator.with_repo(Repo, &Ecto.Migrator.run(&1, :up, config))
  end
end
