[![Tests Status](https://github.com/rickhull/nostrb/actions/workflows/tests.yaml/badge.svg)](https://github.com/rickhull/nostrb/actions/workflows/tests.yaml)

# Nostrb

This is a simple, minimal library written Ruby for working with
[Nostr Events](https://nostr.com/the-protocol/events),
which are like Tweets but are used with the
[Nostr protocol](https://en.wikipedia.org/wiki/Nostr).
Events are cryptographically signed and verified with
[Schnorr Signatures](https://en.wikipedia.org/wiki/Schnorr_signature), per
[NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md)
(Nostr Improvement Protocol).

## Rationale

The library is oriented around Nostr Events, which are the fundamental objects
in the Nostr universe.  It provides everything needed to process incoming
events, including signature verification, as well as most everything needed
to generate outbound events, as a Nostr client or source.

While networking is not provided (yet), storage for relays is handled by
SQLite, with optional Sequel support.

# Usage

This library is provided as a RubyGem.  It has a single direct dependency on
[schnorr_sig](https://github.com/rickhull/schnorr_sig),
which has its own dependencies.

## Install

Locally: `gem install nostrb`

Or add to your project Gemfile: `gem 'nostrb'`

## Example

```ruby
require 'nostrb/source'

# generate secret key, public key
sk, pk = SchnorrSig.keypair

# client needs a public key
client = Nostrb::Source.new(pk)

# create a message
hello = client.text_note('hello world')

# sign it with the secret key
signed = hello.sign(sk)

# create a request to publish
msg = Source.publish(signed)  # => '["EVENT", {...}]'
```

## Dependencies

This library has one necessary dependency on `schnorr_sig`, which itself
depends on two mostly Ruby gems, `ecdsa` and `ecdsa_ext`.

### Optional

`schnorr_sig` also has an optional dependency on `rbsecp256k1`, which is
highly recommended and will be used automatically if the gem is installed.
This provides a dramatic speedup to Schnorr Signature operations as well
as additional correctness and security guarantees.

Nostrb has three optional dependencies:

* `oj` - An alternative to Ruby's stdlib JSON parser/generator
* `sqlite3` - necessary/useful only for running a Relay
* `sequel` - optional layer on top of sqlite3

If `oj` is not installed, then Ruby's stdlib will be used.  If `sqlite3` is
not installed, then `require 'nostrb/relay'` will fail with a `LoadError`.
If `sequel` is not installed, then `require 'nostrb/sequel'` will fail with
a `LoadError`.

Call `Nostrb.gem_check` to check availability of optional dependencies:

```ruby
require 'nostrb'

Nostrb.gem_check
# { "rbsecp256k1"=>Secp256k1,
#   "oj"=>Oj,
#   "sqlite3"=>SQLite3,
#   "sequel"=>Sequel }

# or perhaps:
# { "rbsecp256k1"=>false,
#   "oj"=>false,
#   "sqlite3"=>SQLite3,
#   "sequel"=>false }
```

The second version is the minimum required to run a Nostr relay.

## Fundamentals

### Keys

A public key is required to create an Event.  A secret key is required to
sign an Event.  This library never stores secret keys;
once a secret key is used to create a signature, it falls out out scope and
is never stored or referenced again.

### Event

An Event starts as a chunk of text, the *content*.  Set *kind* to 1,
indicating "text note".  We need a public key, *pubkey*.  We may have an
array of *tags*, but let's assume not.  We are ready to sign.

### Signature

Signing time sets off a chain of dependent events.  We need something to sign,
typically a hash of the message.  But we want to hash more than just the
content.  We need to include pubkey, kind, tags, and also a timestamp.

1. Generate timestamp `created_at`
2. Create serialization: `[version, pubkey, created_at, kind, tags, content]`
   (version=0)
3. Create SHA256 digest of the serialization, store as `id`
4. Create signature `sig` by signing the digest with the secret key

So we will serialize the event including several fields,
hash the serialization, and sign the hash.  Note that the timestamp
(`created_at`) is fundamentally **immutable**, so until an event is signed,
it is somewhat incoherent to refer to its timestamp, serialization, or id.
It's possible to create and examine a *provisional* timestamp, serialization,
or id, but when signing time comes, a new timestamp will be set, and any
previous serialization or digest will be invalid.

### Primary Event Types

* `text_note(content)` kind=1 *make a post*
* `user_metadata(profile)` kind=0 *upload user profile*
* `follow_list(pubkeys)` kind=3 *follow these users*
* `deletion_request(event_ids)` kind=5 *delete these events*

### Client Requests

Nostr clients have 3 fundamental requests

* `publish(event) -> EVENT` *make a post, upload user profile, etc*
* `subscribe(subscription_id, filters) -> REQ`
  *request published events per filter(s)*
* `close(subscription_id) -> CLOSE` *enough events; close subscription*

### Relay Responses

* Client: `EVENT` (post an event)
* Relay: `OK` (acknowledge)

* Client: `REQ` (subscribe to posted events)
* Relay: `EVENT` (send an event)
* Relay: `EVENT` (send another event)
* Relay: `EOSE` (end of sent events)

* Client: `CLOSE` (close subscription opened with REQ)
* Relay: `CLOSED` (confirm subscription closed)

#### Error Handling

* Client: `EVENT` (unparseable)
* Relay: `NOTICE` (error msg)

* Client: `EVENT` (extra fields)
* Relay: `NOTICE` (error msg)

* Client: `EVENT` (fields missing)
* Relay: `NOTICE` (error msg)

* Client: `EVENT` (field format errors)
* Relay: `NOTICE` (error msg)

* Client: `EVENT` (signature fails verification)
* Relay: `OK` (OK:false)

* Client: `EVENT` (id fails verification)
* Relay: `OK` (OK:false)

### Library Structure

* `module Nostrb`: encapsulates this library; provides utility functions
  * `class Event`: a basic Event
    * `content` *String*
    * `kind` *Integer*
    * `pubkey` *String, hex[64]*
    * `tags` *Array[Array[String]]*
  * `class SignedEvent`: upon signing, wraps an Event
    * `created_at` *Integer*
    * `id` *String, hex[64]*
    * `sig` *String, hex[128]*
  * `class Source`: wraps a public key; provides methods for Event creation
    * `text_note(content)` *standard post*
    * `user_metadata(name:, about:, picture:)` *upload profile*
    * `follow_list(pubkeys)` *who to follow*
    * `deletion_request(explanation, event_ids)` *delete events*
  * `class Server`: ingests Events and provides response logic for Nostr relays
    * `event -> EVENT` *return event(s) to client*
    * `ok -> OK` *acknowledge request*
    * `eose -> EOSE` *End Of Sent Events*
    * `closed -> CLOSED` *close a subscription*
    * `notice -> NOTICE` *notifications and errors*
