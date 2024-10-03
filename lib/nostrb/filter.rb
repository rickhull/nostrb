require 'set'

module Nostrb
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

    # e.g. Filter.new(kind: 0, limit: 10).since(days: 1)
    def initialize(id: nil, author: nil, kind: nil, limit: nil)
      @ids = Set.new
      @ids.add id unless id.nil?
      @authors = Set.new
      @authors.add author unless author.nil?
      @kinds = Set.new
      @kinds.add kind unless kind.nil?
      @tags = {}
      @since = Filter.ago(days: 1)
      @until = nil
      @limit = limit
    end

    def to_s
      self.to_h.to_s
    end

    def add_ids(*event_ids)
      @ids.merge event_ids.each { |id| Nostrb.id!(id) }
    end

    def add_authors(*pubkeys)
      @authors.merge pubkeys.each { |pubkey| Nostrb.pubkey!(pubkey) }
    end

    def add_kinds(*kinds)
      @kinds.merge kinds.each { |k| Nostrb.kind!(k) }
    end

    def add_tag(letter, list)
      @tags[Nostrb.txt!(letter, length: 1)] =
        Nostrb.ary!(list, max: 99).each { |s| Nostrb.txt!(s) }
    end

    def since(hsh = nil)
      return @since if hsh.nil?
      @since = Filter.ago(hsh)
      self
    end

    def since=(int)
      @since = int.nil? ? nil : Nostrb.int!(int)
    end

    def until(hsh = nil)
      return @until if hsh.nil?
      @until = Filter.ago(hsh)
      self
    end

    def until=(int)
      @until = int.nil? ? nil : Nostrb.int!(int)
    end

    def limit=(int)
      @limit = int.nil? ? nil : Nostrb.int!(int)
    end

    # Input
    #   Ruby hash as returned from SignedEvent.validate!
    def match?(valid)
      return false if !@ids.empty?     and !@ids.include?(valid["id"])
      return false if !@authors.empty? and !@authors.include?(valid["pubkey"])
      return false if !@kinds.empty?   and !@kinds.include?(valid["kind"])
      return false if !@since.nil?     and @since > valid["created_at"]
      return false if !@until.nil?     and @until < valid["created_at"]
      if !@tags.empty?
        tags = valid["tags"]
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
      h["ids"] = @ids.to_a if !@ids.empty?
      h["authors"] = @authors.to_a if !@authors.empty?
      h["kinds"] = @kinds.to_a if !@kinds.empty?
      @tags.each { |letter, ary|
        h['#' + letter.to_s] = ary if !ary.empty?
      }
      h["since"] = @since unless @since.nil?
      h["until"] = @until unless @until.nil?
      h["limit"] = @limit unless @limit.nil?
      h.freeze
    end
  end
end
