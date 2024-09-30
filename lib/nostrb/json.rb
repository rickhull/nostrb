require 'json'

module Nostrb
  # per NIP-01
  JSON_OPTIONS = {
    allow_nan: false,
    max_nesting: 4,     # event is 3 deep, wire format is 4 deep
    script_safe: false,
    ascii_only: false,
    array_nl: '',
    object_nl: '',
    indent: '',
    space: '',
    space_before: '',
  }

  def self.parse(json) = JSON.parse(json, **JSON_OPTIONS).freeze
  def self.json(object) = JSON.generate(object, **JSON_OPTIONS).freeze
end
