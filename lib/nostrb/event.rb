require 'nostrb/user' # project
require 'digest'      # stdlib
require 'schnorr_sig' # gem

module Nostr
  class Event
    class Error < RuntimeError; end
    class KeyError < Error; end

    # id: 32 bytes (hex = 64)
    # pubkey: 32 bytes (hex = 64)
    # created_at: unix seconds
    # kind: 0..65535
    # tags: []
    # content: "hello world"
    # sig: 64 bytes (hex = 128)

    # the id is a SHA256 of the serialized event:
    # [
    #   0,
    #   <pubkey, lowercase hex>,
    #   <created at>,
    #   <kind>,
    #   <tags>,
    #   <content>
    # ]

    # 1. using public key:
    # 1a. generate content: "hello world"
    # 1b. set kind
    # 1c. set tags
    # 2. digest:
    # 2a. timestamp
    # 2b. generate id: SHA256(json_array)
    # 3. using private key:
    # 3a. sign SHA256(id)

    KINDS = {
      set_metadata: 0,
      text_note: 1,
      # recommend_server: 2, deprecated
      contact_list: 3,
      encrypted_direct_message: 4,
    }

    # raise or return an integer up to 40_000
    def self.kind(val)
      case val
      when 1, 4
        val # ok
      when 0, 3
        val # replaceable
      when 5..999
        val # ?
      when 1000..10_000
        val # regular
      when 10_000..20_000
        val # replaceable
      when 20_000..30_000
        val # ephemeral
      when 30_000..40_000
        val # parameterized replaceable
      when 2, :recommend_server
        raise(Error, "kind value 2 is deprecated")
      else
        KINDS.fetch(val)
      end
    end

    # Input
    #   name: string
    #   (about: string)
    #   (picture: string)
    #   pubkey: 64 byte hexadecimal string, ASCII
    # Output
    #   Event
    #     kind: 0, set_metadata
    #     content: {name: <username>, about: <string>, picture: <url, string>}
    def self.set_metadata(name:, about: '', picture: '', pubkey:, **kwargs)
      hash = kwargs.merge({ name:, about:, picture:, })
      self.new(Nostr.json(hash), kind: 0, pubkey:)
    end

    def self.text_note(content, pubkey:)
      self.new(content, kind: 1, pubkey:)
    end

    # Input
    #   pubkey_hsh: a ruby hash of the form
    #     "deadbeef1234abcdef" => ["wss://alicerelay.com/", "alice"]
    def self.contact_list(pubkey_hsh, pubkey:)
      e = self.new('', kind: 3, pubkey:)
      pubkey_hsh.each { |pubkey, ary|
        e.ref_pubkey(Nostr.hex!(pubkey, 64), *(ary or Array.new))
      }
      e
    end

    attr_reader :content, :kind, :created_at, :pubkey, :signature

    def initialize(content = '', kind: :text_note, pubkey:)
      @content = Nostr.typecheck!(content, String)
      @kind = Event.kind(kind)
      @pubkey = Nostr.hex!(pubkey, 64)
      @tags = []
      @created_at = nil
      @digest = nil
      @signature = nil
    end

    # conditionally initialize @created_at, return ruby array
    def serialize
      [0,
       @pubkey,
       @created_at ||= Time.now.to_i,
       @kind,
       @tags,
       @content]
    end

    # assign @digest, return 32 bytes binary
    def digest(memo: true)
      return @digest if memo and @digest

      # we are creating or recreating the event
      @created_at = nil
      @digest = Digest::SHA256.digest Nostr.json(self.serialize)
    end

    # return 64 bytes of hexadecimal, ASCII encoded
    def id
      SchnorrSig.bin2hex self.digest(memo: true)
    end

    # assign @signature, return 64 bytes binary
    def sign(secret_key)
      Nostr.binary!(secret_key, 32)
      @signature = SchnorrSig.sign(secret_key, self.digest(memo: true))
    end

    # return 128 bytes of hexadecimal, ASCII encoded
    def sig
      SchnorrSig.bin2hex(@signature) if @signature
    end

    # return a Ruby hash, suitable for JSON conversion to NIPS01 Event object
    def object
      {
        id: self.id,
        pubkey: @pubkey,
        created_at: @created_at,
        kind: @kind,
        tags: @tags,
        content: @content,
        sig: self.sig,
      }
    end

    def json
      Nostr.json(self.object)
    end

    # add an array of 2+ strings to @tags
    def add_tag(tag, value, *rest)
      @tags.push([Nostr.typecheck!(tag, String),
                  Nostr.typecheck!(value, String)] +
                 rest.each { |s| Nostr.typecheck!(s, String) })
    end

    # add an event tag based on event id, hex encoded
    def ref_event(eid_hex, *rest)
      add_tag('e', Nostr.hex!(eid_hex, 64), *rest)
    end

    # add a pubkey tag based on pk, 32 bytes binary
    def ref_pk(pk, *rest)
      add_tag('p', SchnorrSig.bin2hex(Nostr.binary!(pk, 32)), *rest)
    end

    # add a pubkey tag based on pubkey, 64 bytes hex encoded
    def ref_pubkey(pk_hex, *rest)
      add_tag('p', Nostr.hex!(pk_hex, 64), *rest)
    end

    # kind: and one of [pubkey:, pk:] required
    def ref_replace(*rest, kind:, pubkey: nil, pk: nil, d_tag: nil)
      raise(ArgumentError, "public key required") if pubkey.nil? and pk.nil?
      pubkey ||= SchnorrSig.bin2hex(pk)
      val = [Event.kind(kind), Nostr.hex!(pubkey, 64), d_tag].join(':')
      add_tag('a', val, *rest)
    end
  end
end
