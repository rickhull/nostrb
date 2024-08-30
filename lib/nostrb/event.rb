require 'nostrb'      # project
require 'digest'      # stdlib

module Nostr
  class Event
    # id: 64 hex chars (32B binary)
    # pubkey: 64 hex chars (32B binary)
    # created_at: unix seconds, integer
    # kind: 0..65535
    # tags: Array[Array[string]]
    # content: any string
    # sig: 128 hex chars (64B binary)

    # the id is a SHA256 digest of the serialized event:
    # [ 0,
    #   <pubkey, lowercase hex>,
    #   <created at>,
    #   <kind>,
    #   <tags>,
    #   <content> ]

    # Event Creation
    # ---
    # 1. given: content, public key, kind, (tags)
    # 2. generate timestamp: Integer, unix timestamp
    # 3. generate id: SHA256, 32B binary, 64B hex
    # 4. sign(secret_key): 64B binary, 128B hex

    class Error < RuntimeError; end
    class BoundsError < Error; end
    class FrozenError < Error; end
    class IdCheck < Error; end
    class SignatureCheck < Error; end

    # deconstruct and typecheck, return a ruby hash
    # this should correspond directly to Event#to_h
    # may raise TypeError (expecting JSON hash/object)
    # may raise KeyError on Hash#fetch
    def self.hash(json_str)
      h = Nostr.parse(json_str)
      raise(TypeError, "Hash expected: #{h.inspect}") unless h.is_a? Hash
      { id:             Nostr.hex!(h.fetch("id"), 64),
        pubkey:         Nostr.hex!(h.fetch("pubkey"), 64),
        kind:       Nostr.integer!(h.fetch("kind")),
        content:     Nostr.string!(h.fetch("content")),
        tags:          Nostr.tags!(h.fetch("tags")),
        created_at: Nostr.integer!(h.fetch("created_at")),
        sig:            Nostr.hex!(h.fetch("sig"), 128), }
    end

    # create JSON array serialization
    # this should correspond directly to Event#serialize and Event#to_s
    # may raise KeyError on Hash#fetch
    def self.serialize(hash)
      Nostr.json([0,
                  hash.fetch(:pubkey),
                  hash.fetch(:created_at),
                  hash.fetch(:kind),
                  hash.fetch(:tags),
                  hash.fetch(:content),])
    end

    # validate the id (optional) and signature
    # may raise IdCheck and SignatureCheck
    def self.verify(json_str, check_id: true)
      h = self.hash(json_str)

      # check the id
      id = SchnorrSig.hex2bin(h.fetch(:id))
      if check_id and id != Digest::SHA256.digest(self.serialize(h))
        raise(IdCheck, h.fetch(:id))
      end

      # verify the signature
      unless SchnorrSig.verify?(SchnorrSig.hex2bin(h.fetch(:pubkey)),
                                id,
                                SchnorrSig.hex2bin(h.fetch(:sig)))
        raise(SignatureCheck, h[:sig])
      end
      h
    end

    attr_reader :content, :kind, :created_at, :pubkey, :signature

    def initialize(content = '', kind: 1, pubkey:)
      @content = Nostr.string!(content)
      @kind = Nostr.integer!(kind)
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

    # JSON string, the array from serialize() above
    def to_s
      Nostr.json(self.serialize)
    end

    # assign @digest, return 32 bytes binary
    def digest(memo: true)
      return @digest.to_s if memo and @digest

      # we are creating or recreating the event
      @created_at = nil
      @digest = Digest::SHA256.digest(self.to_s)
    end

    # return 64 bytes of hexadecimal, ASCII encoded
    def id
      SchnorrSig.bin2hex self.digest(memo: true)
    end

    # return a Ruby hash, suitable for JSON conversion to NIPS01 Event object
    def to_h
      { id: self.id,
        pubkey: @pubkey,
        created_at: @created_at,
        kind: @kind,
        tags: @tags,
        content: @content,
        sig: self.sig.to_s }
    end

    def to_json
      signed? ? Nostr.json(self.to_h) : self.to_s
    end

    # assign @signature, return 64 bytes binary
    # signing will reset created_at and thus the digest / id
    def sign(secret_key)
      @signature = SchnorrSig.sign(Nostr.binary!(secret_key, 32),
                                   self.digest(memo: false))
      self
    end

    def signed?
      !!@signature
    end

    # return 128 bytes of hexadecimal, ASCII encoded
    def sig
      @signature and SchnorrSig.bin2hex(@signature.to_s)
    end

    # add an array of 2+ strings to @tags
    def add_tag(tag, value, *rest)
      raise(FrozenError) if signed?
      @digest = nil # invalidate any prior digest
      @tags.push([Nostr.string!(tag), Nostr.string!(value)] +
                 rest.each { |s| Nostr.string!(s) })
    end

    # add an event tag based on event id, hex encoded
    def ref_event(eid_hex, *rest)
      add_tag('e', Nostr.hex!(eid_hex, 64), *rest)
    end

    # add a pubkey tag based on pubkey, 64 bytes hex encoded
    def ref_pubkey(pk_hex, *rest)
      add_tag('p', Nostr.hex!(pk_hex, 64), *rest)
    end

    # kind: and one of [pubkey:, pk:] required
    def ref_replace(*rest, kind:, pubkey: nil, pk: nil, d_tag: '')
      raise(ArgumentError, "public key required") if pubkey.nil? and pk.nil?
      pubkey ||= SchnorrSig.bin2hex(pk.to_s)
      val = [Nostr.integer!(kind), Nostr.hex!(pubkey, 64), d_tag].join(':')
      add_tag('a', val, *rest)
    end
  end
end
