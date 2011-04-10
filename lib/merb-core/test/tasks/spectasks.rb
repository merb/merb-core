# encoding: UTF-8

require 'rspec/core/rake_task'

desc "Run specs, run a specific spec with TASK=spec/path_to_spec.rb"
task :spec => [ "spec:default" ]

namespace :spec do
  RSpec::Core::RakeTask.new('default') do |t|
    t.pattern = ENV['TASK'] || 'spec/**/*_spec.rb'
  end

  desc "Run all model specs, run a spec for a specific Model with MODEL=MyModel"
  RSpec::Core::RakeTask.new('model') do |t|
    if(ENV['MODEL'])
      t.pattern = "spec/models/**/#{ENV['MODEL']}_spec.rb"
    else
      t.pattern = 'spec/models/**/*_spec.rb'
    end
  end

  desc "Run all request specs, run a spec for a specific Request with REQUEST=MyRequest"
  RSpec::Core::RakeTask.new('request') do |t|
    if(ENV['REQUEST'])
      t.pattern = "spec/requests/**/#{ENV['REQUEST']}_spec.rb"
    else
      t.pattern = 'spec/requests/**/*_spec.rb'
    end
  end

  desc "Run all controller specs, run a spec for a specific Controller with CONTROLLER=MyController"
  RSpec::Core::RakeTask.new('controller') do |t|
    if(ENV['CONTROLLER'])
      t.pattern = "spec/controllers/**/#{ENV['CONTROLLER']}_spec.rb"
    else
      t.pattern = 'spec/controllers/**/*_spec.rb'
    end
  end

  desc "Run all view specs, run specs for a specific controller (and view) with CONTROLLER=MyController (VIEW=MyView)"
  RSpec::Core::RakeTask.new('view') do |t|
    if(ENV['CONTROLLER'] and ENV['VIEW'])
      t.pattern = "spec/views/**/#{ENV['CONTROLLER']}/#{ENV['VIEW']}*_spec.rb"
    elsif(ENV['CONTROLLER'])
      t.pattern = "spec/views/**/#{ENV['CONTROLLER']}/*_spec.rb"
    else
      t.pattern = 'spec/views/**/*_spec.rb'
    end
  end

  desc "Run all specs and output the result in html"
  RSpec::Core::RakeTask.new('html') do |t|
    t.rspec_opts = ["--format", "html"]
    t.pattern = 'spec/**/*_spec.rb'
  end

  desc "Run specs and check coverage with rcov"
  RSpec::Core::RakeTask.new('coverage') do |t|
    t.pattern = 'spec/**/*_spec.rb'
    t.rcov = true
    t.rcov_opts = ["--exclude 'config,spec,#{Gem::path.join(',')}'"]
  end
end
