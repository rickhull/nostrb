require 'nostrb/event'

include Nostr

puts "Key Generation"
sk, pk, hk = Nostr.keys
puts "Secret key: #{SchnorrSig.bin2hex(sk)}"
puts "Public key: #{hk}"
puts

puts "Hello World"
puts "==========="
puts

puts "Unsigned JSON"
hello = Event.new('hello world', pubkey: hk)
puts hello.to_json
puts

puts "Unsigned Object"
puts hello.to_h
puts

hello.sign(sk)
puts "Signed Object"
puts hello.to_h
puts

puts "Signed JSON"
puts hello.to_json
puts

puts
puts "Tagged Event"
puts "============"
puts

puts "Unsigned JSON"
tagged = Event.new('goodbye world', pubkey: hk)
tagged.ref_event(hello.id)
puts tagged.to_json
puts

puts "Unsigned Object"
puts tagged.to_h
puts

puts "Signed Object"
tagged.sign(sk)
puts tagged.to_h
puts

puts "Signed JSON"
puts tagged.to_json
