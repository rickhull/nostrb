require 'json'

module Nostr
  class Error < RuntimeError; end
  class EncodingError < Error; end
  class SizeError < Error; end

  # raise or return val
  def self.typecheck!(val, cls)
    raise(TypeError, "#{cls} : #{val.inspect}") unless val.is_a? cls
    val
  end

  # raise or return str
  def self.binary!(str, length = nil)
    Nostr.typecheck!(str, String)
    raise(EncodingError, str.encoding) if str.encoding != Encoding::BINARY
    if length and length != str.bytesize
      raise(SizeError, "#{length} : #{str.bytesize}")
    end
    str
  end

  # raise or return str
  def self.hex!(str, length = nil)
    Nostr.typecheck!(str, String)
    raise(EncodingError, str.encoding) if str.encoding == Encoding::BINARY
    if length and length != str.bytesize
      raise(SizeError, "#{length} : #{str.bytesize}")
    end
    str
  end

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

  # return a ruby object, likely hash or array
  def self.parse(json)
    JSON.parse(json, **JSON_OPTIONS)
  end

  # convert a ruby object, likely hash or array, return a string of JSON
  def self.json(object)
    JSON.generate(object, **JSON_OPTIONS)
  end
end
