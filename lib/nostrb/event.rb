require 'nostrb'

module Nostrb
  class Event

    # Event
    #   content: any string
    #   kind: 0..65535
    #   tags: Array[Array[string]]
    #   pubkey: 64 hex chars (32B binary)

    def self.digest(ary) = Nostrb.digest(Nostrb.json(Nostrb.ary!(ary)))

    def self.tag_values(tag, tags)
      tags.select { |a| a[0] == tag }.map { |a| a[1] }
    end

    def self.d_tag(tags)
      tag_values('d', tags).first
    end

    def self.freeze_tags(tags)
      tags.each { |a|
        a.each { |s| s.freeze }
        a.freeze
      }
      tags.freeze
    end

    attr_reader :content, :kind, :tags, :pk

    def initialize(content = '', kind: 1, tags: [], pk:)
      @content = Nostrb.txt!(content) # frozen
      @kind    = Nostrb.kind!(kind)
      @tags    = Nostrb.tags!(tags)
      @pk      = Nostrb.key!(pk)      # frozen
    end

    alias_method :to_s, :content

    def serialize(created_at)
      [0, self.pubkey, Nostrb.int!(created_at), @kind, @tags, @content].freeze
    end

    def freeze
      Event.freeze_tags(@tags)
      self
    end

    def to_a = serialize(Time.now.to_i)
    def pubkey = SchnorrSig.bin2hex(@pk)
    def digest(created_at) = Event.digest(serialize(created_at))
    def sign(sk) = SignedEvent.new(self.freeze, sk)

    #
    # Tags
    #

    # add an array of 2+ strings to @tags
    def add_tag(tag, value, *rest)
      @tags.push([Nostrb.txt!(tag), Nostrb.txt!(value)] +
                 rest.each { |s| Nostrb.txt!(s) })
    end

    # add an event tag based on event id, hex encoded
    def ref_event(eid_hex, *rest)
      add_tag('e', Nostrb.id!(eid_hex), *rest)
    end

    # add a pubkey tag based on pubkey, 64 bytes hex encoded
    def ref_pubkey(pubkey, *rest)
      add_tag('p', Nostrb.pubkey!(pubkey), *rest)
    end

    # kind: and pubkey: required
    def ref_replace(*rest, kind:, pubkey:, d_tag: '')
      val = [Nostrb.kind!(kind), Nostrb.pubkey!(pubkey), d_tag].join(':')
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
      Nostrb.check!(parsed, Hash)
      Nostrb.txt!(parsed.fetch("content"))
      Nostrb.pubkey!(parsed.fetch("pubkey"))
      Nostrb.kind!(parsed.fetch("kind"))
      Nostrb.tags!(parsed.fetch("tags"))
      Event.freeze_tags(parsed['tags'])
      Nostrb.int!(parsed.fetch("created_at"))
      Nostrb.id!(parsed.fetch("id"))
      Nostrb.sig!(parsed.fetch("sig"))
      parsed.freeze
    end

    def self.digest(valid) = Nostrb.digest(Nostrb.json(serialize(valid)))

    def self.serialize(valid)
      Array[ 0,
             valid["pubkey"],
             valid["created_at"],
             valid["kind"],
             valid["tags"],
             valid["content"], ].freeze
    end

    # Validate the id (optional) and signature
    # May raise explicitly: IdCheck, SignatureCheck
    # May raise implicitly: Nostrb::SizeError, EncodingError, TypeError,
    #                       SchnorrSig::Error
    # Return a _completely validated_ hash
    def self.verify(valid, check_id: true)
      id, pubkey, sig = valid["id"], valid["pubkey"], valid["sig"]

      # extract binary values for signature verification
      digest = SchnorrSig.hex2bin id
      pk = SchnorrSig.hex2bin pubkey
      signature = SchnorrSig.hex2bin sig

      # verify the signature
      unless SchnorrSig.verify?(pk, digest, signature)
        raise(SignatureCheck, sig)
      end
      # (optional) verify the id / digest
      raise(IdCheck, id) if check_id and digest != SignedEvent.digest(valid)
      valid
    end

    attr_reader :event, :created_at, :digest, :signature

    # sk is used to generate @signature and then discarded
    def initialize(event, sk)
      @event = Nostrb.check!(event, Event)
      @created_at = Time.now.to_i
      @digest = @event.digest(@created_at).freeze
      @signature = SchnorrSig.sign(Nostrb.key!(sk), @digest).freeze
    end

    def content = @event.content
    def kind = @event.kind
    def tags = @event.tags
    def pubkey = @event.pubkey
    def to_s = @event.to_s
    def serialize = @event.serialize(@created_at)

    def id = SchnorrSig.bin2hex(@digest).freeze
    def sig = SchnorrSig.bin2hex(@signature).freeze

    def to_h
      Hash[ "content" => @event.content,
            "kind" => @event.kind,
            "tags" => @event.tags,
            "pubkey" => @event.pubkey,
            "created_at" => @created_at,
            "id" => self.id,
            "sig" => self.sig ].freeze
    end
  end
end
