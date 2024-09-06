require 'nostrb/event'

# per NIP-01

module Nostr
  class EventServer
    def self.event(sid, event) = ["EVENT", Nostr.sid!(sid), event.to_h]
    def self.ok(eid, msg = "", ok: true)
      ["OK", Nostr.id!(eid), !!ok, ok ? Nostr.txt!(msg) : Nostr.help!(msg)]
    end
    def self.eose(sid) = ["EOSE", Nostr.sid!(sid)]
    def self.closed(sid, msg) = ["CLOSED", Nostr.sid!(sid), Nostr.help!(msg)]
    def self.notice(msg) = ["NOTICE", Nostr.txt!(msg)]
  end
end
