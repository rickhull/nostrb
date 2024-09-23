require 'nostrb/sequel'

include Nostrb::Sequel

puts Setup.new.setup

writer = Writer.new
reader = Reader.new

# create event
sk, pk = SchnorrSig.keypair
event = Nostrb::Event.new('', pk: pk).sign(sk)
puts "Created Event"
puts event.to_h
puts

# store event
writer.add_event(event.to_h)

# retrieve event
hsh = reader.process_events.first
puts hsh
puts

# compare to original
puts "Faithful retrieval: #{hsh == event.to_h ? 'SUCCESS' : 'FAIL'}"
puts

# create new event with tags
e2 = Nostrb::Event.new('yo', pk: pk)
e2.ref_event(event.id)
e2 = e2.sign(sk)
puts "Created Event with tags"
puts e2.to_h
puts

# store event
writer.add_event(e2.to_h)

# retrieve event
hsh = {}
reader.process_events.each { |h|
  if h['id'] == e2.id
    hsh = h
    puts "Retrieved Event"
    puts hsh
    puts
  end
}

# compare to original
puts "Faithful retrieval: #{hsh == e2.to_h ? 'SUCCESS' : 'FAIL'}"
puts
