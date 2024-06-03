Gem::Specification.new do |s|
  s.name = 'nostrb'
  s.summary = "Minimal Nostr library in Ruby"
  s.description = "TBD"
  s.authors = ["Rick Hull"]
  s.homepage = "https://github.com/rickhull/nostrb"
  s.license = "LGPL-2.1-only"

  s.required_ruby_version = "~> 3.0"

  s.version = File.read(File.join(__dir__, 'VERSION')).chomp

  s.files = %w[nostrb.gemspec VERSION Rakefile]
  s.files += Dir['lib/**/*.rb']
  s.files += Dir['test/**/*.rb']
  # s.files += Dir['demo/**/*.rb']

  s.add_dependency "schnorr_sig", "~> 0.2"
end
