defmodule Deck.Owner do
  use Deck.Schema

  @type t() :: %Deck.Owner{
          discord_user_id: binary(),
          id: String.t(),
          public_key: binary()
        }

  schema "owners" do
    field :public_key, :binary, null: false
    field :discord_user_id, :string, null: false
  end
end
