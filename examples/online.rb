require 'nostrb/client'
require 'set'

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
  rw || wo || ro || ''
end

def pubkey_petname(profile)
  raise("wrong event kind") unless profile['kind'] == 0
  { profile['pubkey'] => {
      relay: nil,
      petname: Nostrb.parse(profile['content']).fetch('name'),
    }
  }
end

relay_url ='wss://localhost:7070'

c = Nostrb::Client.new(relay_url)

reg = {}
%w[homer marge bart lisa maggie].each { |name|
  sk, pk = SchnorrSig.keypair
  reg[name] = {
    sk: sk,
    pk: pk,
    src: Nostrb::Source.new(pk)
  }
}

# Bart uploads his profile
bart = reg['bart'][:src]
sk = reg['bart'][:sk]
p = bart.profile(name: 'bart',
                 about: 'bart',
                 picture: 'bart').sign(sk)
puts "Bart's profile: #{p}"
puts c.publish(p)
puts

# Bart uploads preferred relay(s)
r = bart.relay_list({ relay_url => :read_write }).sign(sk)
puts "Bart's relay list: #{r.tags}"
puts c.publish(r)
puts

# Marge requests profile pubkeys
marge = reg['marge'][:src]
sk = reg['marge'][:sk]
pubkeys = {}
f = Nostrb::Filter.new(kind: 0).since(seconds: 5)
puts "Marge's filter: #{f}"
c.subscribe(f) { |e|
  puts "Event: #{e}"
  pubkeys.update(pubkey_petname(e))
}
puts "Pubkeys: #{pubkeys}"
puts

# Marge reqests preferred relay(s)
f = Nostrb::Filter.new(kind: 10002).since(seconds: 5)
f.add_authors *pubkeys.keys
puts "Marge's filter: #{f}"
c.subscribe(f) { |e|
  puts "Event: #{e}"
  pubkeys[e['pubkey']][:relay] = best_relay(e['tags'])
}
puts "Pubkeys: #{pubkeys}"
puts

# Marge follows Bart
f = marge.follow_list(pubkeys.select { |pk, h|
                        h[:petname] == 'bart'
                      }.to_h).sign(sk)
puts "Marge follows: #{f.tags}"
puts c.publish(f)
puts


# Marge uploads her profile
p = marge.profile(name: 'marge',
                 about: 'marge',
                 picture: 'marge').sign(sk)
puts "Marge's profile: #{p}"
puts c.publish(p)
puts

# Marge uploads her preferred relays
r = marge.relay_list({ relay_url => :read_write }).sign(sk)
puts "Marge's relay list: #{r.tags}"
puts c.publish(r)
puts

# Homer requests recent profiles; discovers Marge's and Bart's pubkeys
homer = reg['homer'][:src]
sk = reg['homer'][:sk]

pubkeys = {}
f = Nostrb::Filter.new(kind: 0).since(seconds: 5)
puts "Homer's filter: #{f}"
c.subscribe(f) { |e|
  puts "Event: #{e}"
  pubkeys.update(pubkey_petname(e))
}
puts "Pubkeys: #{pubkeys}"
puts

# Homer reqests preferred relay(s)
f = Nostrb::Filter.new(kind: 10002).since(seconds: 5)
f.add_authors(*pubkeys.keys)
puts "Homer's filter: #{f}"
c.subscribe(f) { |e|
  puts "Event: #{e}"
  pubkeys[e['pubkey']][:relay] = best_relay(e['tags'])
}
puts "Pubkeys: #{pubkeys}"
puts


# Homer follows Marge
f = homer.follow_list(pubkeys.select { |pk, hsh|
                        hsh[:petname] == 'marge'
                      }.to_h).sign(sk)
puts "Homer follows: #{f.tags}"
puts c.publish(f)
puts

# Lisa uploads her profile
lisa = reg['lisa'][:src]
sk = reg['lisa'][:sk]
p = lisa.profile(name: 'lisa',
                 about: 'lisa',
                 picture: 'lisa').sign(sk)
puts "Lisa's profile: #{p}"
puts c.publish(p)
puts

# Lisa uploads her preferred relays
r = lisa.relay_list({ relay_url => :read_write }).sign(sk)
puts "Lisa's relay list: #{r.tags}"
puts c.publish(r)
puts

# Maggie uploads her profile
maggie = reg['maggie'][:src]
sk = reg['maggie'][:sk]
p = maggie.profile(name: 'maggie',
                   about: 'maggie',
                   picture: 'maggie').sign(sk)
puts "Maggie's profile: #{p}"
puts c.publish(p)
puts


# Maggie uploads her preferred relays
r = maggie.relay_list({ relay_url => :read_write }).sign(sk)
puts "Maggie's relay list: #{r.tags}"
puts c.publish(r)
puts

# Marge requests recent profiles; discovers Lisa, Maggie
sk = reg['marge'][:sk]
pubkeys = {}
f = Nostrb::Filter.new(kind: 0).since(seconds: 5)
puts "Marge's filter: #{f}"
c.subscribe(f) { |e|
  puts "Event: #{e}"
  pubkeys.update(pubkey_petname(e))
}
puts "Pubkeys: #{pubkeys}"
puts

# Marge reqests preferred relay(s)
f = Nostrb::Filter.new(kind: 10002).since(seconds: 5)
f.add_authors *pubkeys.keys
puts "Marge's filter: #{f}"
c.subscribe(f) { |e|
  puts "Event: #{e}"
  pubkeys[e['pubkey']][:relay] = best_relay(e['tags'])
}
puts "Pubkeys: #{pubkeys}"
puts

# Marge follows Bart, Lisa, Maggie
f = marge.follow_list(pubkeys.select { |pk, hsh|
                        hsh[:petname] == 'bart' or
                          hsh[:petname] == 'lisa' or
                          hsh[:petname] == 'maggie'
                      }.to_h).sign(sk)
puts "Marge follows: #{f.tags}"
puts c.publish(f)
puts

# Homer requests Marge's recent follows; discovers Lisa and Maggie
marge_pk = pubkeys.select { |pk, hsh| hsh[:petname] == 'marge' }.keys.first
raise(pubkeys.inspect) if marge_pk.nil?
f = Nostrb::Filter.new(kind: 3, author: marge_pk).since(seconds: 5)
puts "Homer's filter: #{f}"
c.subscribe(f) { |e|
  puts "Event: #{e}"
}
puts
