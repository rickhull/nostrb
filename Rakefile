require 'rake/testtask'

Rake::TestTask.new :test do |t|
  t.pattern = "test/*.rb"
  t.warning = true
end

Rake::TestTask.new :test_less do |t|
  t.pattern = "test/{[!r][!e][!l][!a][!y]}*.rb"
  t.warning = true
end

task :relay do |t|
  sh "bundle exec falcon serve --bind wss://localhost:7070"
end

task default: [:test]

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
