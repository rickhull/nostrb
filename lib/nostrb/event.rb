require 'nostrb'

# Kind:
#   0,3: replaceable -- relay stores only the last message from pubkey
#   2: deprecated
#   1,4..44,1000..9999: regular -- relay stores all
#   10_000..19_999: replaceable -- relay stores latest(pubkey, kind)
#   20_000..29_999: ephemeral -- relay doesn't store
#   30_000..39_999: parameterized replaceable -- latest(pubkey, kind, dtag)

# for replaceable events with same timestamp, lowest id wins

module Nostr
  class Event

    # Event
    #   content: any string
    #   pubkey: 64 hex chars (32B binary)
    #   kind: 0..65535
    #   tags: Array[Array[string]]

    def self.digest(ary) = Nostr.digest(Nostr.json(Nostr.ary!(ary)))

    attr_reader :content, :pk, :kind, :tags

    def initialize(content = '', pk:, kind: 1, tags: [])
      @content = Nostr.txt!(content)
      @pk      = Nostr.key!(pk)
      @kind    = Nostr.kind!(kind)
      @tags    = Nostr.tags!(tags)
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
      @tags.push([Nostr.txt!(tag), Nostr.txt!(value)] +
                 rest.each { |s| Nostr.txt!(s) })
    end

    # add an event tag based on event id, hex encoded
    def ref_event(eid_hex, *rest)
      add_tag('e', Nostr.id!(eid_hex), *rest)
    end

    # add a pubkey tag based on pubkey, 64 bytes hex encoded
    def ref_pubkey(pubkey, *rest)
      add_tag('p', Nostr.pubkey!(pubkey), *rest)
    end

    # kind: and pubkey: required
    def ref_replace(*rest, kind:, pubkey:, d_tag: '')
      val = [Nostr.kind!(kind), Nostr.pubkey!(pubkey), d_tag].join(':')
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

    def self.validate!(parsed)
      Nostr.check!(parsed, Hash)
      Nostr.txt!(parsed.fetch("content"))
      Nostr.pubkey!(parsed.fetch("pubkey"))
      Nostr.kind!(parsed.fetch("kind"))
      Nostr.tags!(parsed.fetch("tags"))
      Nostr.int!(parsed.fetch("created_at"))
      Nostr.id!(parsed.fetch("id"))
      Nostr.sig!(parsed.fetch("sig"))
      parsed
    end

    def self.digest(valid) = Nostr.digest(Nostr.json(serialize(valid)))

    def self.serialize(valid)
      Array[ 0,
             valid["pubkey"],
             valid["created_at"],
             valid["kind"],
             valid["tags"],
             valid["content"], ]
    end

    # Validate the id (optional) and signature
    # May raise explicitly: IdCheck, SignatureCheck
    # May raise implicitly: Nostr::SizeError, EncodingError, TypeError,
    #                       SchnorrSig::Error
    # Return a _completely validated_ hash
    def self.verify(parsed, check_id: true)
      hash = validate!(parsed)

      id, pubkey, sig = hash["id"], hash["pubkey"], hash["sig"]

      # extract binary values for signature verification
      digest = SchnorrSig.hex2bin id
      pk = SchnorrSig.hex2bin pubkey
      signature = SchnorrSig.hex2bin sig

      # verify the signature
      unless SchnorrSig.verify?(pk, digest, signature)
        raise(SignatureCheck, sig)
      end
      # (optional) verify the id / digest
      raise(IdCheck, id) if check_id and digest != SignedEvent.digest(hash)
      hash
    end

    attr_reader :event, :created_at, :digest, :signature

    # sk is used to generate @signature and then discarded
    def initialize(event, sk)
      @event = Nostr.check!(event, Event)
      @created_at = Time.now.to_i
      @digest = @event.digest(@created_at)
      @signature = SchnorrSig.sign(Nostr.key!(sk), @digest)
    end

    def to_s = @event.to_s
    def id = SchnorrSig.bin2hex(@digest)
    def sig = SchnorrSig.bin2hex(@signature)

    def to_h
      Hash[ "content" => @event.content,
            "pubkey" => @event.pubkey,
            "kind" => @event.kind,
            "tags" => @event.tags,
            "created_at" => @created_at,
            "id" => self.id,
            "sig" => self.sig ]
    end
  end
end
