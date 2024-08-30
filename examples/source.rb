require 'nostrb/source'

# generate marge keys
marge_sk, pk, hk = Nostr.keys

# create a message using the public key
marge = Nostr::Source.new(pk: pk)
hello = marge.text_note('Good morning, Homie')

puts "Marge Simpson: hello world"
puts

puts "Serialized"
p hello.serialize
puts

# sign the message with the secret key
hello.sign(marge_sk)

puts "Event Object"
puts hello.to_json
puts

#####

# bring our own secret key; generate the public key
homer_sk, pk, hk = Nostr.keys(Random.bytes(32))

# create a message using the public key
homer = Nostr::Source.new(pk: pk)
response = homer.text_note('Good morning, Marge')

# reference an earlier message
response.ref_event(hello.id)

puts
puts "Homer: hello back, private key, ref prior event"
puts

puts "Serialized"
p response.serialize
puts

# sign the message with the secret key
response.sign(homer_sk)

puts "Event Object"
puts response.to_json
puts

#####

maggie_sk, pk, hk = Nostr.keys
maggie = Nostr::Source.new(pk: pk)

puts
puts "Maggie: love letter, ref Marge's pubkey"
puts

love_letter = maggie.text_note("Dear Mom,\nYou're the best.\nLove, Maggie")
love_letter.ref_pubkey(marge.pubkey)

puts "Serialized"
p love_letter.serialize
puts

love_letter.sign(maggie_sk)

puts "Event Object"
puts love_letter.to_json
puts

#####

puts
puts "Bart uploads his profile"
puts


bart_sk, bart_pk, hk = Nostr.keys
bart = Nostr::Source.new(pk: pk)
profile = bart.set_metadata(name: 'Bart',
                            about: 'Bartholomew Jojo Simpson',
                            picture: 'https://upload.wikimedia.org' +
                            '/wikipedia/en/a/aa/Bart_Simpson_200px.png')

puts "Serialized"
p profile.serialize
puts

profile.sign(bart_sk)

puts "Event Object"
puts profile.to_json
puts

puts "Profile Content"
puts profile.content
puts

#####

puts
puts "Lisa follows her family"
puts

lisa_sk, pk, hk = Nostr.keys
lisa = Nostr::Source.new(pk: pk)

pubkey_hsh = {
  marge.pubkey => ["wss://thesimpsons.com/", "marge"],
  homer.pubkey => ["wss://thesimpsons.com/", "homer"],
  bart.pubkey => ["wss://thesimpsons.com/", "bart"],
  maggie.pubkey => ["wss://thesimpsons.com/", "maggie"],
}

following = lisa.contact_list(pubkey_hsh)

puts "Serialized"
p following.serialize
puts

following.sign(lisa_sk)

puts "Event Object"
puts following.to_json
