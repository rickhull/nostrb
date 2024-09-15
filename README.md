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

Zero networking or storage is handled by this library at this time.  While
that may be added in the future, the limited goal of this library is to
provide the fundamentals related to Nostr Events that a client or relay may
need.

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
2. Create serialization: `[pubkey, created_at, kind, tags, content]`
3. Create SHA256 digest of the serialization, store as `id`
4. Create signature `sig` by signing the digest with the secret key

So we will serialize the event including several fields,
hash the serialization, and sign the hash.  Note that the timestamp is
fundamentally **immutable**, so until an event is signed, it is somewhat
incoherent to refer to its timestamp, serialization, or id.  We can always
create and examine a *provisional* timestamp, serialization, or id.  But when
signing time comes, a new timestamp will be set, and any previous
serialization or digest will be invalid.

### Library Structure

* `module Nostrb`: encapsulates this library; provides utility functions
  * `class Event`: a basic Event with no handling for `created_at`, `id`, `sig`
  * `class SignedEvent`: upon signing, wraps an Event with
    `created_at`, `id`, `sig`
  * `class Source`: wraps a public key; provides methods for Event creation
