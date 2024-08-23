require 'schnorr_sig'
require 'json'

module Nostr
  SS = SchnorrSig

  #
  # Type Enforcement
  #

  # raise SS::TypeError or return str
  def self.string!(str)
    SS.string!(str) and str
  end

  # raise SS::TypeError or return int
  def self.integer!(int)
    SS.integer!(int) and int
  end

  # raise SS::TypeError or SS::SizeError or return ary
  def self.array!(ary, length = nil)
    raise(SS::TypeError, ary.class) unless ary.is_a?(Array)
    raise(SS::SizeError, ary.length) if length and length != ary.length
    ary
  end

  # Array[Array[String]]
  # calls Nostr.array!, above; may raise SS::TypeError
  def self.tags!(ary)
    array!(ary).each { |a| array!(a).each { |s| Nostr.string! s } }
  end

  # raise (SS::EncodingError, SS::SizeError) or return str
  def self.binary!(str, length = nil)
    SS.string!(str)
    raise(SS::EncodingError, str.encoding) if str.encoding != Encoding::BINARY
    raise(SS::SizeError, str.length) if length and length != str.length
    str
  end

  # raise (SS::EncodingError, SS::SizeError) or return str
  def self.hex!(str, length = nil)
    SS.string!(str)
    raise(SS::EncodingError, str.encoding) if str.encoding == Encoding::BINARY
    raise(SS::SizeError, str.length) if length and length != str.length
    str
  end

  #
  # JSON I/O
  #

  # per NIP-01
  JSON_OPTIONS = {
    allow_nan: false,
    max_nesting: 3,
    script_safe: false,
    ascii_only: false,
    array_nl: '',
    object_nl: '',
    indent: '',
    space: '',
    space_before: '',
  }

  # convert a string of JSON; return a ruby object, likely hash or array
  def self.parse(json)
    JSON.parse(json, **JSON_OPTIONS)
  end

  # convert a ruby object, likely hash or array; return a string of JSON
  def self.json(object)
    JSON.generate(object, **JSON_OPTIONS)
  end
end
