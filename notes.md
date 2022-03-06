# TCG Notes

I want to build an experience where multiple
users can create their own cards and control
the rarity and authenticity of each card
they've created.

## File Format

Each user will "own" their own database. How
this is stored is not super important, but
i want to use a SQLite DB. It will have a
handful of tables:

* owners - indexed by "public key"
* root_owner - link to an `owner` entry with
               the accompanying private key
* cards - cards owned by the root_owner
* card_blocks - belongs to a card, all blocks
                make up a card
* inventory - contains pre-rendered instances of cards?

## Inventory

Each DB will contain an table full of cards they "own".
Each entry into this table represents a card that was minted
using it's original blocks.  I think some cryptography
is required here. 

Do i need to prove that a particular entry was created by a set of blocks??
mabye i'm wanting something but it's not really that interesting to anyone else. 
Reads like an NFT fanfic. Maybe it's better if each card is completley unique
and can't be shared. What's there to "collect" with an inventory?

## Authenticity

each entry in the `cards` table holds the
instructions (via `card_blocks`) to render
a card. Each card also contains a hash of the
blocks that make it that will be used to
calculate if a card is authentic or not.
Each card also has a unique identifier
(read: serial number) assosiated with it
that should be rendered
somewhere discrete on the card - pokemon cards
have this

## Engine

The engine should be a piece of software that takes in
a file, and outputs cards in image formats. maybe webp
since i believe it can animate?

the engine will need to interface with sqlite3, lua and
some sort of image manipulation API. This should be very
portable so that it can be put "inside" of many other programs.
ideally, it should be able to run in all the following contexts:

* flutter for frontend and native apps
* phoenix backend
* command line
* "editor" program (may be the flutter app, dunno yet)

I've picked Zig as the main language for this and lua
as the "interface" language for cards to be constructed with.
Lua code can be compiled with `luac` and put into a block.
I think this should be the only "required" block for each
card. Images will be their own block as well, accessible via
the interface lua api. This should be implemented in zig
rather than lua such that the contents of the sqlite database
are not made accessable to the card itself. I will need to
create a strong specification between the "card" record
and how it is rendered. I think "versioning" each block
for the required engine version to work will be important to
nail very early as changes to the engine could break
rendering old cards.

## Backend

The backend should be responsible for keeping a repository
of all users's databases. a database of databases if you will.
It should also be the final source of truth if any trades have
taken place. There will be a catch-22 here of sorts where
if an offline transfer happens, all parties involved will
need to "confirm" it. probably implement that last lmao.

If the backend has it's own file, it can be automated into
delivering random cards, or even gambling lol

## Core Mechanics

for every card a user has, they should be able
to:

* view their own cards
* give away cards
* destroy cards
* make more cards
* offer cards as trade

This means everyone will have to create their
own card, and "mint" as many as they want to be
circulated

## Experience

I'd like this to be linked to discord primarily
but the ability to trade cards offline would
be really cool.

By making the "engine" be a portable piece of
software that simply outputs an image, many
"apps" can be made. Im thinking of using
Flutter to build a cross platform application.

of course by allowing offline transactions,
this will mean whatever central "backend" will
need to understand how to either replay or
merge database together. An issue i see with that is
desyncing. I'm still thinking of a way to implement this
with the least amount of work. Something something cap
theorem.

A diff algorithm can probably be implemented since
the data is all formatted very specifically.

The `owners` table can grow, but never change. The root
owner table also can never change.

`cards` could "fork" from the last known sync with the
single file format concept. I think in this case, the solution
will be to simply "not allow" forking: IE: the backend
is always the source of truth.

The only reason i want offline trades is to allow trading
at matg where internet is sparse. Doing this over NFC
will make the experience feel "real"

## Encryption

The file format is just an SQLite database, so it can be
encrypted using either the official sqlite encryption
library one of the OSS implementations. Will need to
see about integrating with Zig. i'm sure it's not hard.

~~The file can be encrypted with the private key that gets
generated when creating a new db~~

Maybe that should be a completely different private key,
to prevent unwanted modifications to the database

## feature: NFC

It would be cool to have a mobile app that can scan an NFC
sticker on a real pyhsical card, and have it contain enough
data to render itself. The data allowed to be stored on
an NFC sticker isn't big enough for all that, so either a
**super** compressed format could be implemented, or the
sticker could contain a "link" of sorts to the backend
that injects tthe card into the database. This is again,
how pokemon worked for pre wifi event pokemon.

## feature: animated cards

The entire reason of going thru all of this work is to have
the "engine" be something that can execute code and output
data. I think a way to output a gif would be very cool. This
could be the analogous of a "holographic" card. or similar.

I looked briefely into using opengl shaders for this but
it's a little too complex, and i don't know if webgl supports
that. I think exposing a function in the script called "update"
or something of the sort will suffice.

doing this will allow cards to fundementally change such that
you wouldn't get the same data every time if implemented incorrectly.

I think it's important to always output the same data no matter
what the condition to preserve authenticity. I'm not exactly sure
how that works just yet, but i'm quite certain it's possible.

This means that i should stay away from allowing the following
functionality to the engine's interpreter environment:

* rng - duh, doing this will allow non-deterministic values
* http - can't be downloading new images every time it runs
* record alteration - don't want to allow altering records that make up the card
* access to time functions - time alway the same.
  * workaround for this one is to allow "creation date" to be exposed
* asdf

some cool features that would be fun:

* rotate asset
* change text
  * marquee lol
* text color?
* arbitrary drawing?
* "predefined" actions?
* generated "users online" images

## feature: seen cards

it would be cool to have another table of "seen" cards. Again, similar to pokemnon.
If anything, i think this will discourage "duplicating" cards. As i write this
i just realized that the concept of needing all the blocks to mint a card makes no
sense, since to trade it away, you'd need to give all the blocks that make it as well.
This means users will need an `inventory` and i will need to rethink how `cards` are madeup...

okay i'm back from rethinking. there's nothing that makes this any better than any other file browser/image viewer.
if someone asks for this, i'll make it, but there's nothing special about it.

This did make me reconsider how cards even work. there's no reason to make more than one of a card which is kind of boring.
Maybe there's something to making a card that deterministicly changes on how many times it's been viewed.
woah that's really neat of an idea. Instead of making them always output the same data every time, they could be encouraged
to do something different every time the engine renders it. only the db that owns the card can make it do "special" shit.

I think a hybrid of both is probably the real answer. under "normal" conditions, rendering the card would output
the same image every time. A user could also render "special" cards running it thru the engine. that would create "unique" instances
that would never appear again meaning the resulting image would only exist once.

a special event might include trading or gifting.

example use cases i can think of:

every time a card is traded, the photo gets slightly more transparent until it's eventually only able to generate a card with no content.

every time a card is given away, blah blah blah

for consideration: card interact? come back to this later
