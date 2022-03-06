defmodule Deck.CardBlock do
  use Deck.Schema
  alias Deck.Card

  @type t() :: %Deck.CardBlock{
          card: Ecto.Association.NotLoaded.t() | Card.t(),
          card_id: String.t(),
          data: binary(),
          id: String.t(),
          name: String.t()
        }

  schema "card_blocks" do
    belongs_to :card, Card
    field :data, :binary, null: false
    field :name, :string, null: false
  end
end
