require 'nostrb/sqlite'
require 'nostrb/event'

include Nostrb

# setup database
setup = Setup.new
setup.create_tables
puts setup.report
puts

# create event
sk, pk = SchnorrSig.keypair
event = Event.new('', pk: pk).sign(sk)
puts "Created Event"
puts event.to_h
puts

# store event
writer = Writer.new
writer.add_event event.to_h

# retrieve event
reader = Reader.new
rs = reader.select_events
hsh = reader.add_tags(rs.next_hash)
puts "Retrieved Event"
puts hsh
puts

# compare to original
puts "Faithful retrieval: #{hsh == event.to_h ? 'SUCCESS' : 'FAIL'}"
puts


# create new event with tags
e2 = Event.new('yo', pk: pk)
e2.ref_event(event.id)
e2 = e2.sign(sk)
puts "Created Event with tags"
puts e2.to_h
puts

# store event
writer.add_event e2.to_h

# retrieve event
rs = reader.select_events
hsh = {}
rs.each_hash { |h|
  if h['id'] == e2.id
    hsh = reader.add_tags(h)
    puts "Retrieved Event"
    puts h
    puts
  end
}

# compare to original
puts "Faithful retrieval: #{hsh == e2.to_h ? 'SUCCESS' : 'FAIL'}"
puts
