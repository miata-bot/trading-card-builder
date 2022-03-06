defmodule Deck.RootOwner do
  use Deck.Schema

  @type t() :: %Deck.RootOwner{
          id: 0,
          owner: Ecto.Association.NotLoaded.t(),
          owner_id: String.t(),
          private_key: binary()
        }

  schema "root_owner" do
    belongs_to :owner, Deck.Owner
    field :private_key, :binary, null: false
  end
end
