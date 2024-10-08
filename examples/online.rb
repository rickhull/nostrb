require 'nostrb/client'
require 'set'

include Nostrb

# Bart uploads his profile; pubkey now discoverable
# Marge requests recent profiles; discovers Bart's pubkey
# Marge follows Bart
# Marge uploads her profile
# Homer requests recent profiles; discovers Marge's and Bart's pubkeys
# Homer follows Marge
# Lisa uploads her profile
# Maggie uploads her profile
# Marge requests recent profiles; discovers Lisa, Maggie
# Marge follows Bart, Lisa, Maggie
# Homer requests Marge's recent follows; discovers Lisa and Maggie

def best_relay(tags)
  rw, wo, ro = nil, nil, nil
  tags.each { |(tag, value, flag)|
    next unless tag == 'r'
    case flag
    when '', nil
      rw = value
    when 'write'
      wo = value
    when 'read'
      ro = value
    else
      raise("unexpected: #{flag.inspect}")
    end
  }
  rw or wo or ro or ''
end

def timestamp msg
  puts Nostrb.stamp(msg)
end

relay_url ='wss://localhost:7070'
c = Client.new(relay_url)

reg = {}
%w[homer marge bart lisa maggie].each { |name|
  sk, pk = SchnorrSig.keypair
  reg[name] = {
    sk: sk,
    pk: pk,
    src: Source.new(pk)
  }
}
timestamp "Built Registry"

# Bart uploads his profile
bart = reg['bart'][:src]
sk = reg['bart'][:sk]
p = bart.profile(name: 'bart',
                 about: 'bart',
                 picture: 'bart').sign(sk)
timestamp "Bart's profile: #{p}"
timestamp c.publish(p)
puts

# Bart uploads preferred relay(s)
r = bart.relay_list({ relay_url => :read_write }).sign(sk)
timestamp "Bart's relay list: #{r.tags}"
timestamp c.publish(r)
puts

# Marge requests profile pubkeys
marge = reg['marge'][:src]
sk = reg['marge'][:sk]
pubkeys = {}
f = Filter.new(kind: 0).since(seconds: 5)
timestamp "Marge's filter: #{f}"
c.subscribe(f) { |edata|
  puts "Event: #{edata.to_h}"
  pubkeys[edata.pubkey] = {
    relay: nil,
    petname: Nostrb.parse(edata.content).fetch('name'),
  }
}
timestamp "Pubkeys: #{pubkeys}"
puts

# Marge reqests preferred relay(s)
f = Filter.new(kind: 10002).since(seconds: 5)
f.add_authors *pubkeys.keys
timestamp "Marge's filter: #{f}"
c.subscribe(f) { |edata|
  puts "Event: #{edata.to_h}"
  pubkeys[edata.pubkey][:relay] = best_relay(edata.tags)
}
timestamp "Pubkeys: #{pubkeys}"
puts

# Marge follows Bart
f = marge.follow_list(pubkeys.select { |pk, h|
                        h[:petname] == 'bart'
                      }.to_h).sign(sk)
timestamp "Marge follows: #{f.tags}"
timestamp c.publish(f)
puts

# Marge uploads her profile
p = marge.profile(name: 'marge',
                 about: 'marge',
                 picture: 'marge').sign(sk)
timestamp "Marge's profile: #{p}"
timestamp c.publish(p)
puts

# Marge uploads her preferred relays
r = marge.relay_list({ relay_url => :read_write }).sign(sk)
timestamp "Marge's relay list: #{r.tags}"
timestamp c.publish(r)
puts

# Homer requests recent profiles; discovers Marge's and Bart's pubkeys
homer = reg['homer'][:src]
sk = reg['homer'][:sk]

pubkeys = {}
f = Filter.new(kind: 0).since(seconds: 5)
timestamp "Homer's filter: #{f}"
c.subscribe(f) { |edata|
  puts "Event: #{edata.to_h}"
  pubkeys[edata.pubkey] = {
    relay: nil,
    petname: Nostrb.parse(edata.content).fetch('name'),
  }
}
timestamp "Pubkeys: #{pubkeys}"
puts

# Homer reqests preferred relay(s)
f = Filter.new(kind: 10002).since(seconds: 5)
f.add_authors(*pubkeys.keys)
timestamp "Homer's filter: #{f}"
c.subscribe(f) { |edata|
  puts "Event: #{edata.to_h}"
  pubkeys[edata.pubkey][:relay] = best_relay(edata.tags)
}
timestamp "Pubkeys: #{pubkeys}"
puts


# Homer follows Marge
f = homer.follow_list(pubkeys.select { |pk, hsh|
                        hsh[:petname] == 'marge'
                      }.to_h).sign(sk)
timestamp "Homer follows: #{f.tags}"
timestamp c.publish(f)
puts

# Lisa uploads her profile
lisa = reg['lisa'][:src]
sk = reg['lisa'][:sk]
p = lisa.profile(name: 'lisa',
                 about: 'lisa',
                 picture: 'lisa').sign(sk)
timestamp "Lisa's profile: #{p}"
timestamp c.publish(p)
puts

# Lisa uploads her preferred relays
r = lisa.relay_list({ relay_url => :read_write }).sign(sk)
timestamp "Lisa's relay list: #{r.tags}"
timestamp c.publish(r)
puts

# Maggie uploads her profile
maggie = reg['maggie'][:src]
sk = reg['maggie'][:sk]
p = maggie.profile(name: 'maggie',
                   about: 'maggie',
                   picture: 'maggie').sign(sk)
timestamp "Maggie's profile: #{p}"
timestamp c.publish(p)
puts


# Maggie uploads her preferred relays
r = maggie.relay_list({ relay_url => :read_write }).sign(sk)
timestamp "Maggie's relay list: #{r.tags}"
timestamp c.publish(r)
puts


# Marge requests recent profiles; discovers Lisa, Maggie
sk = reg['marge'][:sk]
pubkeys = {}
f = Filter.new(kind: 0).since(seconds: 5)
timestamp "Marge's filter: #{f}"
c.subscribe(f) { |edata|
  puts "Event: #{edata.to_h}"
  pubkeys[edata.pubkey] = {
    relay: nil,
    petname: Nostrb.parse(edata.content).fetch('name'),
  }
}
timestamp "Pubkeys: #{pubkeys}"
puts


# Marge reqests preferred relay(s)
f = Filter.new(kind: 10002).since(seconds: 5)
f.add_authors *pubkeys.keys
timestamp "Marge's filter: #{f}"
c.subscribe(f) { |edata|
  puts "Event: #{edata.to_h}"
  puts "Tags: #{edata.tags}"
  pubkeys[edata.pubkey][:relay] = best_relay(edata.tags)
}
timestamp "Pubkeys: #{pubkeys}"
puts

# Marge follows Maggie, Lisa, Bart
babies = %w[maggie lisa bart].freeze
f = marge.follow_list(pubkeys.select { |pk, hsh|
                        babies.include? hsh[:petname]
                      }.to_h).sign(sk)
timestamp "Marge follows: #{f.tags}"
timestamp c.publish(f)
puts


# Homer requests Marge's recent follows; discovers Lisa and Maggie
homer = reg['homer'][:src]
sk = reg['homer'][:sk]
marge_pk = pubkeys.select { |pk, hsh| hsh[:petname] == 'marge' }.keys.first
raise(pubkeys.inspect) if marge_pk.nil?
f = Filter.new(kind: 3, author: marge_pk).since(seconds: 5)

timestamp "Homer's filter: #{f}"
pkh = {}
c.subscribe(f) { |e|
  e.tags.each { |(tag, pubkey, relay, petname)|
    next unless tag == 'p' and %w[maggie lisa].include? petname
    pkh[pubkey] = {
      petname: petname,
      relay: relay,
    }
  }
}

f = homer.follow_list(pkh).sign(sk)
timestamp "Homer follows: #{f.tags}"
timestamp c.publish(f)
puts
