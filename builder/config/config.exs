import Config

config :builder, Deck.Repo,
  priv: "priv/repo/",
  # database: "deleteme.db",
  migration_primary_key: [name: :id, type: :uuid]

config :builder, ecto_repos: [Deck.Repo]
