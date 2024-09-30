require 'oj'

module Nostrb
  def self.parse(json)  = Oj.load(json, mode: :strict).freeze
  def self.json(object) = Oj.dump(object, mode: :strict).freeze
end
