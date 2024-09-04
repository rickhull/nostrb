require 'schnorr_sig'
require 'json'
require 'digest'

module Nostr
  class Error < RuntimeError; end
  class SizeError < Error; end

  #######################################
  # Type Checking and Enforcement

  # raise TypeError or return val
  def self.check!(val, cls)
    val.is_a?(cls) ? val : raise(TypeError, "#{cls} expected: #{val.inspect}")
  end

  def self.int!(int) = check!(int, Integer)

  # enforce String
  # enforce encoding (optional)
  # enforce length (optional)
  # return str
  def self.str!(str, binary: nil, length: nil)
    check!(str, String)
    if !binary.nil? and !binary == (str.encoding == Encoding::BINARY)
      raise(EncodingError, str.encoding)
    end
    raise(SizeError, str.length) if !length.nil? and length != str.length
    str
  end

  # enforce binary String, length(optional); return str
  def self.binary!(str, length = nil)
    str!(str, binary: true, length: length)
  end

  # enforce nonbinary String, length(optional); return str
  def self.text!(str, length = nil)
    str!(str, binary: false, length: length)
  end

  # enforce Array[Array[String(nonbinary)]]; return ary
  def self.tags!(ary)
    check!(ary, Array).each { |a|
      check!(a, Array).each { |s| Nostr.text!(s) }
    }
  end


  #####################################
  # JSON I/O

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
  def self.parse(json) = JSON.parse(json, **JSON_OPTIONS)

  # convert a ruby object, likely hash or array; return a string of JSON
  def self.json(object) = JSON.generate(object, **JSON_OPTIONS)


  ####################################
  # Utilities

  # return 32 bytes binary
  def self.digest(str) = Digest::SHA256.digest(str)

  # return [secret key (hex), public key (hex)]
  def self.keypair = SchnorrSig.keypair.map { |bin| SchnorrSig.bin2hex(bin) }
end
