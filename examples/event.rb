require 'nostrb/event'

include Nostr

puts "Key Generation"
secret_key, pubkey = Nostr.keypair
puts "Secret key: #{secret_key}"
puts "Public key: #{pubkey}"
puts

puts "Hello World"
puts "==========="
puts

puts "Unsigned JSON"
hello = Event.new('hello world', pubkey: pubkey)
puts hello.to_json
puts

puts "Unsigned Object"
puts hello.to_h
puts

hello.sign(secret_key)
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
tagged = Event.new('goodbye world', pubkey: pubkey)
tagged.ref_event(hello.id)
puts tagged.to_json
puts

puts "Unsigned Object"
puts tagged.to_h
puts

puts "Signed Object"
tagged.sign(secret_key)
puts tagged.to_h
puts

puts "Signed JSON"
puts tagged.to_json
