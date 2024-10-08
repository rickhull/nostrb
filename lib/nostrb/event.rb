require 'nostrb'

module Nostrb
  class Event
    # Event
    #   content: any string
    #   kind: 0..65535
    #   tags: Array[Array[string]]
    #   pubkey: 64 hex chars (32B binary)

    # Kind
    #   1, 4..44, 1000..9999: regular -- relay stores all
    #   0, 3: replaceable -- relay stores only the last message from pubkey
    #   2: deprecated
    #   10_000..19_999: replaceable -- relay stores latest(pubkey, kind)
    #   20_000..29_999: ephemeral -- relay doesn't store
    #   30_000..39_999: parameterized replaceable -- latest(pubkey, kind, dtag)

    # Tag
    #   Array[String]: [tag, value, *rest] - tag is typically a single letter
    # Well Known Tags
    #   a: addressable or replaceable (NIP-01)
    #   d: user_defined_value? addressable? paremeterized replaceable?
    #   e: event_id (NIP-01)
    #   i: external id (NIP-73)
    #   p: public_key (NIP-01)
    #   r: relay_url, or any url
    #   t: hashtag
    #   title: set name (NIP-51) or cal event (NIP-52) or
    #          live event (NIP-53) or listing (NIP-99)

    # SHA256(JSON(Array))
    def self.digest(ary) = Nostrb.digest(Nostrb.json(Nostrb.ary!(ary)))

    # e.g. for every 'p' tag, take the first value; return array of values
    def self.tag_values(tag, tags)
      tags.select { |a| a[0] == tag }.map { |a| a[1] }
    end

    # first d tag's value; for addressable events (parameterized replaceable)
    def self.d_tag(tags)
      tag_values('d', tags).first
    end

    # freeze Array[Array[String]]
    def self.freeze_tags(tags)
      tags.each { |a|
        a.each(&:freeze)  # freeze strings
        a.freeze          # freeze inner array
      }
      tags.freeze         # freeze outer array
    end

    attr_reader :content, :kind, :tags, :pk

    def initialize(content = '', kind: 1, tags: [], pk:)
      @content = Nostrb.txt!(content) # frozen
      @kind    = Nostrb.kind!(kind)
      @tags    = Nostrb.tags!(tags)
      @pk      = Nostrb.key!(pk)      # frozen
    end

    alias_method :to_s, :content
    def to_a = self.serialize(Time.now.to_i)
    def pubkey = SchnorrSig.bin2hex(@pk)
    def digest(created_at) = Event.digest(self.serialize(created_at))
    def serialize(created_at) = [0, self.pubkey, Nostrb.int!(created_at),
                                 @kind, @tags, @content]

    # return SignedEvent (Data class)
    def sign(sk)
      created_at = Time.now.to_i
      digest = self.digest(created_at)
      signature = SchnorrSig.sign(Nostrb.key!(sk), digest)
      SignedEvent.new(content: @content,
                      kind: @kind,
                      tags: @tags,
                      pubkey: self.pubkey,
                      created_at: created_at,
                      id: SchnorrSig.bin2hex(digest),
                      sig: SchnorrSig.bin2hex(signature))
    end

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

    # add a (relay) url
    def ref_url(url, flag = nil, *rest)
      case flag
      when nil, :read_write, 'read_write'
        # ok, RW is default
      when :read, :write, 'read', 'write'
        rest.shift(flag.to_s) # add the flag
      else
        raise("unexpected: #{flag.inspect}")
      end
      add_tag('r', url, *rest)
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

  SignedEvent = ::Data.define(:content, :kind, :tags, :pubkey,
                              :created_at, :id, :sig) do
    def self.ingest(hash)
      self.new(content: hash.fetch('content'),
               kind: hash.fetch('kind'),
               tags: hash.fetch('tags'),
               pubkey: hash.fetch('pubkey'),
               created_at: hash.fetch('created_at'),
               id: hash.fetch('id'),
               sig: hash.fetch('sig'))
    end

    def initialize(content:, kind:, tags:, pubkey:, created_at:, id:, sig:)
      super(content: Nostrb.txt!(content),
            kind: Nostrb.kind!(kind),
            tags: Event.freeze_tags(Nostrb.tags!(tags)),
            pubkey: Nostrb.pubkey!(pubkey),
            created_at: Nostrb.int!(created_at),
            id: Nostrb.id!(id),
            sig: Nostrb.sig!(sig))
    end

    def serialize
      [0, pubkey, created_at, kind, tags, content]
    end

    def valid_sig?
      SchnorrSig.verify?(SchnorrSig.hex2bin(self.pubkey),
                         SchnorrSig.hex2bin(self.id),
                         SchnorrSig.hex2bin(self.sig))
    end

    def valid_id?
      SchnorrSig.hex2bin(self.id) == Event.digest(self.serialize)
    end
  end
end
