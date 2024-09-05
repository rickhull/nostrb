require 'nostrb'

module Nostr
  class Event

    # Event
    #   content: any string
    #   pubkey: 64 hex chars (32B binary)
    #   kind: 0..65535
    #   tags: Array[Array[string]]

    # Convert Hash[symbol => val] to Array[val]
    # This should correspond directly to Event#serialize
    # May raise KeyError on Hash#fetch
    def self.serialize(hash)
      Array[ 0,
             hash.fetch(:pubkey),
             hash.fetch(:created_at),
             hash.fetch(:kind),
             hash.fetch(:tags),
             hash.fetch(:content) ]
    end

    # return 32 bytes binary, the digest of a JSON array
    def self.digest(ary_or_hsh)
      a = ary_or_hsh.is_a?(Hash) ? serialize(ary_or_hsh) : ary_or_hsh
      Nostr.digest(Nostr.json(a))
    end

    attr_reader :content, :pk, :kind, :tags

    def initialize(content = '', pk:, kind: 1, tags: [])
      @content = Nostr.text!(content)
      @pk = Nostr.binary!(pk, 32)
      @kind = Nostr.int!(kind)
      @tags = Nostr.tags!(tags)
    end

    alias_method :to_s, :content

    def serialize(created_at)
      [0, self.pubkey, Nostr.int!(created_at), @kind, @tags, @content]
    end

    def to_a = serialize(Time.now.to_i)
    def pubkey = SchnorrSig.bin2hex(@pk)
    def digest(created_at) = Event.digest(serialize(created_at))
    def sign(sk) = SignedEvent.new(self, sk)

    #
    # Tags
    #

    # add an array of 2+ strings to @tags
    def add_tag(tag, value, *rest)
      @tags.push([Nostr.text!(tag), Nostr.text!(value)] +
                 rest.each { |s| Nostr.text!(s) })
    end

    # add an event tag based on event id, hex encoded
    def ref_event(eid_hex, *rest)
      add_tag('e', Nostr.text!(eid_hex, 64), *rest)
    end

    # add a pubkey tag based on pubkey, 64 bytes hex encoded
    def ref_pubkey(pubkey, *rest)
      add_tag('p', Nostr.text!(pubkey, 64), *rest)
    end

    # kind: and pubkey: required
    def ref_replace(*rest, kind:, pubkey:, d_tag: '')
      val = [Nostr.int!(kind), Nostr.text!(pubkey, 64), d_tag].join(':')
      add_tag('a', val, *rest)
    end
  end

  # SignedEvent
  # id: 64 hex chars (32B binary)
  # created_at: unix seconds, integer
  # sig: 128 hex chars (64B binary)

  class SignedEvent
    class Error < RuntimeError; end
    class IdCheck < Error; end
    class SignatureCheck < Error; end

    # Deconstruct and typecheck, return a ruby hash
    # This should correspond directly to SignedEvent#to_h
    # May raise explicitly: KeyError on Hash#fetch
    # May raise implicitly: Nostr::SizeError, EncodingError, TypeError
    def self.hash(json_str)
      h = Nostr.parse(json_str)
      Nostr.check!(h, Hash)
      Hash[ content:   Nostr.text!(h.fetch("content")),
            pubkey:    Nostr.text!(h.fetch("pubkey"), 64),
            kind:       Nostr.int!(h.fetch("kind")),
            tags:      Nostr.tags!(h.fetch("tags")),
            created_at: Nostr.int!(h.fetch("created_at")),
            id:        Nostr.text!(h.fetch("id"), 64),
            sig:       Nostr.text!(h.fetch("sig"), 128) ]
    end

    # Validate the id (optional) and signature
    # May raise explicitly: IdCheck, SignatureCheck
    # May raise implicitly: Nostr::SizeError, EncodingError, TypeError,
    #                       SchnorrSig::Error
    # Return a _completely validated_ hash
    def self.verify(json_str, check_id: true)
      # validate the json string; we know we have a valid hash now
      h = self.hash(json_str)

      # extract binary values for signature verification
      digest = SchnorrSig.hex2bin(h[:id])
      pk = SchnorrSig.hex2bin(h[:pubkey])
      signature = SchnorrSig.hex2bin(h[:sig])

      # verify the signature
      unless SchnorrSig.verify?(pk, digest, signature)
        raise(SignatureCheck, h[:sig])
      end
      # (optional) verify the id / digest
      raise(IdCheck, h[:id]) if check_id and digest != Event.digest(h)
      h
    end

    attr_reader :event, :created_at, :digest, :signature

    def initialize(event, sk)
      @event = Nostr.check!(event, Event)
      @created_at = Time.now.to_i
      @digest = @event.digest(@created_at)
      @signature = SchnorrSig.sign(Nostr.binary!(sk, 32), @digest)
    end

    def to_s = @event.to_s
    def id = SchnorrSig.bin2hex(@digest)
    def sig = SchnorrSig.bin2hex(@signature)

    def to_h
      Hash[ content: @event.content,
            pubkey: @event.pubkey,
            kind: @event.kind,
            tags: @event.tags,
            created_at: @created_at,
            id: self.id,
            sig: self.sig ]
    end

    def to_json = Nostr.json(self.to_h)
  end
end
