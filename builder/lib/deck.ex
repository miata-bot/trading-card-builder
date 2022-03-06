defmodule Deck do
  defmodule Repo do
    use Ecto.Repo,
      otp_app: :builder,
      adapter: Ecto.Adapters.SQLite3

    alias __MODULE__

    def with_repo(config, fun) do
      default_dynamic_repo = Repo.get_dynamic_repo()

      {:ok, pid} = Repo.start_link(config)

      try do
        Repo.put_dynamic_repo(pid)
        fun.(%{pid: pid, repo: Repo})
      after
        Repo.put_dynamic_repo(default_dynamic_repo)
        Supervisor.stop(pid)
      end
    end
  end

  defmodule Schema do
    defmacro __using__(_) do
      quote do
        use Ecto.Schema
        @primary_key {:id, Ecto.UUID, autogenerate: true}
        @foreign_key_type Ecto.UUID
      end
    end
  end
end
