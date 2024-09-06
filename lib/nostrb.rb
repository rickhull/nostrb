require 'schnorr_sig'
require 'json'
require 'digest'

module Nostr
  class Error < RuntimeError; end
  class SizeError < Error; end

  #######################################
  # Type Checking and Enforcement

  def self.check!(val, cls)
    val.is_a?(cls) ? val : raise(TypeError, "#{cls} expected: #{val.inspect}")
  end

  def self.int!(int, max: nil)
    check!(int, Integer)
    raise(SizeError, "#{int} > #{max} (max)") if !max.nil? and int > max
    int
  end

  def self.kind!(kind)
    int!(kind, max: 65535)
  end

  def self.ary!(ary, max: nil)
    check!(ary, Array)
    if !max.nil? and ary.length > max
      raise(SizeError, "#{ary.length} > #{max} (max)")
    end
    ary
  end

  def self.str!(str, binary: nil, length: nil, max: nil)
    check!(str, String)
    if !binary.nil? and !binary == (str.encoding == Encoding::BINARY)
      raise(EncodingError, str.encoding)
    end
    raise(SizeError, str.length) if !length.nil? and str.length != length
    raise(SizeError, str.length) if !max.nil? and str.length > max
    str
  end

  def self.bin!(str, length: nil, max: nil)
    str!(str, binary: true, length: length, max: max)
  end

  def self.key!(str)
    bin!(str, length: 32)
  end

  def self.txt!(str, length: nil, max: nil)
    str!(str, binary: false, length: length, max: max)
  end

  def self.hexkey!(str)
    txt!(str, length: 64)
  end

  def self.tags!(ary)
    ary!(ary, max: 9999).each { |a| ary!(a, max: 99).each { |s| txt!(s) } }
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

  def self.parse(json) = JSON.parse(json, **JSON_OPTIONS)

  def self.json(object) = JSON.generate(object, **JSON_OPTIONS)

  ####################################
  # Utilities

  # return 32 bytes binary
  def self.digest(str) = Digest::SHA256.digest(str)
end
