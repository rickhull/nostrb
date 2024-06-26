require 'nostrb/user'

puts "Marge Simpson: hello world"
puts

# keypair will be generated
marge = Nostr::User.new(name: 'Marge')
hello = marge.post('Hi Homie')

puts "Serialized"
p hello.serialize
puts

marge.sign(hello)

puts "Event Object"
p hello.object
puts

puts "Event JSON"
puts hello.json
puts

############

puts
puts "goodnight"
puts

goodnight = marge.post('Goodnight Homer')
goodnight.ref_event(hello.id)

puts "Serialized"
p goodnight.serialize
puts

marge.sign(goodnight)

puts "Event Object"
p goodnight.object
puts

puts "Event JSON"
puts goodnight.json
puts

############

puts
puts "homer loves marge"
puts

# use our own secret key; pubkey will be generated
homer = Nostr::User.new(name: 'Homer', about: 'Homer Jay Simpson',
                        sk: Random.bytes(32))
love_letter = homer.post("I love you Marge.\nLove, Homie")
love_letter.ref_pk(marge.pk)

puts "Serialized"
p love_letter.serialize
puts

homer.sign(love_letter)

puts "Event Object"
p love_letter.object
puts

puts "Event JSON"
puts love_letter.json
puts

###########

puts
puts "bart uploads his profile"
puts

# we'll "bring our own" keypair
sk, pk = SchnorrSig.keypair
bart = Nostr::User.new(name: 'Bart',
                       about: 'Bartholomew Jojo Simpson',
                       picture: 'https://upload.wikimedia.org/wikipedia/en/a/aa/Bart_Simpson_200px.png',
                       sk: sk, pk: pk)
profile = bart.profile

puts "Serialized"
p profile.serialize
puts

bart.sign(profile)

puts "Event Object"
p profile.object
puts

puts "Event JSON"
puts profile.json
puts

puts "Profile Content"
puts profile.content
puts

###########

puts
puts "lisa follows her family"
puts

lisa = Nostr::User.new(name: 'Lisa')
following = lisa.follows({ marge.pubkey => ['wss://marge.relay/', 'mom'],
                           homer.pubkey => ['wss://homer.relay/', 'dad'],
                           bart.pubkey  => ['wss://bart.relay/', 'bart'], })

puts "Serialized"
p following.serialize
puts

lisa.sign(following)

puts "Event Object"
p following.object
puts

puts "Event JSON"
puts following.json
puts

############

puts
puts "maggie has an adorable secret key"
puts

maggie = Nostr::User.new(name: 'Maggie', sk: ("\x00" * 16 + "\xFF" * 16).b)
babble = maggie.post("ga ga goo ga *squeal*")

puts "Serialized"
p babble.serialize
puts

maggie.sign(babble)

puts "Event Object"
p babble.object
puts

puts "Event JSON"
puts babble.json
puts

############

puts
puts "lisa follows her family, including maggie"
puts

following = lisa.follows({ marge.pubkey => ['wss://marge.relay/', 'mom'],
                           homer.pubkey => ['wss://homer.relay/', 'dad'],
                           bart.pubkey  => ['wss://bart.relay/', 'bart'],
                           maggie.pubkey => ['wss://maggie.relay/', 'maggie'],
                         })

puts "Serialized"
p following.serialize
puts

lisa.sign(following)

puts "Event Object"
p following.object
puts

puts "Event JSON"
puts following.json
puts
