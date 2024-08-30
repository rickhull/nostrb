require 'rake/testtask'

Rake::TestTask.new :test do |t|
  t.pattern = "test/*.rb"
  t.warning = true
end

task default: :test

task :examples do |t|
  Dir['examples/*.rb'].each { |f|
    sh "ruby #{f}"
  }
end

begin
  require 'buildar'

  Buildar.new do |b|
    b.gemspec_file = 'nostrb.gemspec'
    b.version_file = 'VERSION'
    b.use_git = true
  end
rescue LoadError
  warn "buildar tasks unavailable"
end
