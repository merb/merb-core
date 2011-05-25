require 'rubygems'
require 'rake'
require "rspec/core/rake_task"
require "fileutils"

$:.unshift(File.dirname(__FILE__))

# Load code annotation support library
require File.expand_path("../tools/annotation_extract", __FILE__)

include FileUtils

desc "Run the specs."
task :default => :specs

task :merb => [:clean, :doc, :package]

##############################################################################
# Documentation
##############################################################################
task :doc => [:yard]
begin
  require 'yard'

  YARD::Rake::YardocTask.new do |t|
    t.files   = [File.join('lib', '**', '*.rb'), '-', File.join('docs', '*.mkd')]
    t.options = [
      '--output-dir', 'doc/yard',
      '--tag', 'overridable:Overridable',
      '--markup', 'markdown',
    ]
  end
rescue
end

##############################################################################
# rSpec & rcov
##############################################################################

# Ruby 1.9.2 requires this to run specs
task :setup_local_path do
  $:.unshift(File.dirname(__FILE__)) unless $:.include? File.dirname(__FILE__)
end

desc "Run :spec, :rcov"
task :aok => [:spec, :rcov]

desc "Run coverage suite"
task :rcov do
  require 'fileutils'
  FileUtils.rm_rf("coverage") if File.directory?("coverage")
  FileUtils.mkdir("coverage")
  path = File.expand_path(Dir.pwd)
  files = Dir["spec/**/*_spec.rb"]
  files.each do |spec|
    puts "Getting coverage for #{File.expand_path(spec)}"
    command = %{rcov #{File.expand_path(spec)} --aggregate #{path}/coverage/data.data --exclude ".*" --include-file "lib/merb-core(?!\/vendor)"}
    command += " --no-html" unless spec == files.last
    `#{command} 2>&1`
  end
end

desc "Run all specs; set RAKE_TAG to filter specs (see rspec --tag parameter)"
task :spec do
  Dir['spec/**/*_spec.rb'].each do |file|

    begin
      ruby '-S', 'rspec', file, :verbose => false
    rescue Exception
    end
  end
end
#RSpec::Core::RakeTask.new(:spec) do |t|
#  options = ""
#  options += "--tag #{ENV['RAKE_TAG']}" unless ENV['RAKE_TAG'].nil?
#
#  t.pattern = "spec/**/*_spec.rb"
#  t.rspec_opts = options
#  t.fail_on_error = false
#end

##############################################################################
# CODE STATISTICS
##############################################################################

STATS_DIRECTORIES = [
  ['Code', 'lib/'],
  ['Unit tests', 'spec']
].collect { |name, dir| [ name, "./#{dir}" ] }.
  select  { |name, dir| File.directory?(dir) }

desc "Report code statistics (KLOCs, etc) from the application"
task :stats do
  require File.expand_path("../tools/code_statistics", __FILE__)
  # require "extra/stats"
  verbose = true
  CodeStatistics.new(*STATS_DIRECTORIES).to_s
end

##############################################################################
# SYNTAX CHECKING
##############################################################################

task :check_syntax do
  `find . -name "*.rb" |xargs -n1 ruby -c |grep -v "Syntax OK"`
  puts "* Done"
end


# Run specific tests or test files. Searches nested spec directories as well.
#
# Based on a technique popularized by Geoffrey Grosenbach
rule "" do |t|
  spec_cmd = (RUBY_PLATFORM =~ /java/) ? "jruby -S spec" : "spec"
  # spec:spec_file:spec_name
  if /spec:(.*)$/.match(t.name)
    arguments = t.name.split(':')

    file_name = arguments[1]
    spec_name = arguments[2..-1]

    spec_filename = "#{file_name}_spec.rb"
    specs = Dir["spec/**/#{spec_filename}"]

    if path = specs.detect { |f| spec_filename == File.basename(f) }
      run_file_name = path
    else
      puts "No specs found for #{t.name.inspect}"
      exit
    end

    example = " -e '#{spec_name}'" unless spec_name.empty?

    sh "#{spec_cmd} #{run_file_name} --colour #{example}"
  end
end

##############################################################################
# Flog
##############################################################################

namespace :flog do
  task :worst_methods do
    require "flog"
    flogger = Flog.new
    flogger.flog_files Dir["lib/**/*.rb"]
    totals = flogger.totals.sort_by {|k,v| v}.reverse[0..10]
    totals.each do |meth, total|
      puts "%50s: %s" % [meth, total]
    end
  end
  
  task :total do
    require "flog"
    flogger = Flog.new
    flogger.flog_files Dir["lib/**/*.rb"]
    puts "Total: #{flogger.total}"
  end
  
  task :per_method do
    require "flog"
    flogger = Flog.new
    flogger.flog_files Dir["lib/**/*.rb"]
    methods = flogger.totals.reject { |k,v| k =~ /\#none$/ }.sort_by { |k,v| v }
    puts "Total Flog:    #{flogger.total}"
    puts "Total Methods: #{flogger.totals.size}"
    puts "Flog / Method: #{flogger.total / methods.size}"
  end
end

namespace :tools do
  namespace :tags do
    desc "Generates Emacs tags using Exuberant Ctags."
    task :emacs do
      sh "ctags -e --Ruby-kinds=-f -o TAGS -R lib"
    end
  end
end
