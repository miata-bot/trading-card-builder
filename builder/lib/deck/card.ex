defmodule Deck.Card do
  use Deck.Schema
  alias Deck.{Owner, CardBlock}

  @type t() :: %Deck.Card{
          blocks: Ecto.Association.NotLoaded.t() | [CardBlock.t()],
          creator: Ecto.Association.NotLoaded.t() | Owner.t(),
          creator_id: String.t(),
          hash: String.t(),
          id: String.t()
        }

  schema "cards" do
    belongs_to :creator, Owner
    field :hash, :string, null: false
    has_many :blocks, CardBlock
  end
end
