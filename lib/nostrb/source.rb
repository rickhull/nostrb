require 'nostrb/event'

module Nostr

  #
  # A Source holds a public key and creates Events.
  #

  class Source
    #######################
    # Client Requests

    def self.publish(signed) = ["EVENT", signed.to_h]

    def self.subscribe(sid, *filters)
      ["REQ", Nostr.sid!(sid), *filters.map { |f|
         Nostr.check!(f, Filter).to_h
      }]
    end

    def self.close(sid) = ["CLOSE", Nostr.sid!(sid)]

    #######################
    # Utils / Init

    def self.random_sid
      SchnorrSig.bin2hex Random.bytes(32)
    end

    attr_reader :pk

    def initialize(pk)
      @pk = Nostr.key!(pk)
    end

    def pubkey = SchnorrSig.bin2hex(@pk)

    ############################
    # Event Creation

    #           NIP-01
    def event(content, kind = 1)
      Event.new(content, kind: kind, pk: @pk)
    end
    alias_method :text_note, :event

    #           NIP-01
    # Input
    #   name: string
    #   about: string
    #   picture: string, URL
    # Output
    #   Event
    #     content: {"name":<username>,"about":<string>,"picture":<url>}
    #     kind: 0, user metadata
    def user_metadata(name:, about:, picture:, **kwargs)
      full = kwargs.merge(name: Nostr.txt!(name),
                          about: Nostr.txt!(about),
                          picture: Nostr.txt!(picture))
      event(Nostr.json(full), 0)
    end
    alias_method :profile, :user_metadata

    #           NIP-02
    # Input
    #   pubkey_hsh: a ruby hash of the form: pubkey => [relay_url, petname]
    #     "deadbeef1234abcdef" => ["wss://alicerelay.com/", "alice"]
    # Output
    #   Event
    #     content: ""
    #     kind: 3, follow list
    #     tags: [['p', pubkey, relay_url, petname]]
    def follow_list(pubkey_hsh)
      list = event('', 3)
      pubkey_hsh.each { |pubkey, (url, name)|
        list.ref_pubkey(Nostr.pubkey!(pubkey),
                        Nostr.txt!(url),
                        Nostr.txt!(name))
      }
      list
    end
    alias_method :follows, :follow_list

    #           NIP-09
    # Input
    #   explanation: content string
    #   event_ids: array of event ids, hex format
    # Output
    #   Event
    #     content: explanation
    #     kind: 5, deletion request
    #     tags: [['e', event_id]]
    # TODO: support deletion of replaceable events ('a' tags)
    def deletion_request(explanation, event_ids)
      e = event(explanation, 5)
      event_ids.each { |eid| e.ref_event(eid) }
      e
    end
    alias_method :delete, :deletion_request
  end

  module Seconds
    def milliseconds(i) = i / 1000r
    def seconds(i) = i
    def minutes(i) = 60 * i
    def hours(i)   = 60 * minutes(i)
    def days(i)    = 24 * hours(i)
    def weeks(i)   =  7 * days(i)
    def months(i)  = years(i) / 12
    def years(i)   = 365 * days(i)

    def process(hsh)
      seconds = 0
      [:seconds, :minutes, :hours, :days, :weeks, :months, :years].each { |p|
        seconds += send(p, hsh[p]) if hsh.key?(p)
      }
      seconds
    end
  end
  Seconds.extend(Seconds)

  class Filter
    TAG = /\A#([a-zA-Z])\z/

    def self.ago(hsh)
      Time.now.to_i - Seconds.process(hsh)
    end

    def self.ingest(hash)
      f = Filter.new

      if ids = hash.delete("ids")
        f.add_ids(*ids)
      end
      if authors = hash.delete("authors")
        f.add_authors(*authors)
      end
      if kinds = hash.delete("kinds")
        f.add_kinds(*kinds)
      end
      if since = hash.delete("since")
        f.since = since
      end
      if _until = hash.delete("until")
        f.until = _until
      end
      if limit = hash.delete("limit")
        f.limit = limit
      end

      # anything left in hash should only be single letter tags
      hash.each { |tag, ary|
        if matches = tag.match(TAG)
          f.add_tag(matches[1], ary)
        else
          warn "unmatched tag: #{tag}"
        end
      }
      f
    end

    attr_reader :ids, :authors, :kinds, :tags, :limit

    def initialize
      @ids = []
      @authors = []
      @kinds = []
      @tags = {}
      @since = nil
      @until = nil
      @limit = nil
    end

    def add_ids(*event_ids)
      @ids += event_ids.each { |id| Nostr.id!(id) }
    end

    def add_authors(*pubkeys)
      @authors += pubkeys.each { |pubkey| Nostr.pubkey!(pubkey) }
    end

    def add_kinds(*kinds)
      @kinds += kinds.each { |k| Nostr.kind!(k) }
    end

    def add_tag(letter, list)
      @tags[Nostr.txt!(letter, length: 1)] =
        Nostr.ary!(list, max: 99).each { |s| Nostr.txt!(s) }
    end

    def since(hsh = nil) = hsh.nil? ? @since : (@since = Filter.ago(hsh))
    def since=(int)
      @since = int.nil? ? nil : Nostr.int!(int)
    end

    def until(hsh = nil) = hsh.nil? ? @until : (@until = Filter.ago(hsh))
    def until=(int)
      @until = int.nil? ? nil : Nostr.int!(int)
    end

    def limit=(int)
      @limit = int.nil? ? nil : Nostr.int!(int)
    end

    # Input
    #   Ruby hash as returned from SignedEvent.ingest
    def match?(e_hash)
      return false if !@ids.empty? and !@ids.include?(e_hash[:id])
      return false if !@authors.empty? and !@authors.include?(e_hash[:pubkey])
      return false if !@kinds.empty? and !@kinds.include?(e_hash[:kind])
      return false if @since and @since > e_hash[:created_at]
      return false if @until and @until < e_hash[:created_at]
      if !@tags.empty?
        tags = e_hash[:tags]
        @tags.each { |letter, ary|
          tag_match = false
          tags.each { |(tag, val)|
            next if tag_match
            if tag == letter
              return false if !ary.include?(val)
              tag_match = true
            end
          }
          return false unless tag_match
        }
      end
      true
    end

    def to_h
      h = Hash.new
      h["ids"] = @ids if !@ids.empty?
      h["authors"] = @authors if !@authors.empty?
      h["kinds"] = @kinds if !@kinds.empty?
      @tags.each { |letter, ary|
        h['#' + letter.to_s] = ary if !ary.empty?
      }
      h["since"] = @since unless @since.nil?
      h["until"] = @until unless @until.nil?
      h["limit"] = @limit unless @limit.nil?
      h
    end
  end
end
