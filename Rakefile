# encoding: utf-8
$:.push File.join(File.dirname(__FILE__),'lib')

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'alicorn'
require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "alicorn"
  gem.version = Alicorn::VERSION
  gem.homepage = "http://github.com/bensomers/alicorn"
  gem.license = "MIT"
  gem.summary = %Q{Standalone auto-scaler for unicorn}
  gem.description = %Q{Highly configurable dumb auto-scaler for managing unicorn web servers}
  gem.email = "somers.ben@gmail.com"
  gem.authors = ["Ben Somers"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :test
