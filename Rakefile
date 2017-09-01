$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "lib"))

require "bundler/setup"
require 'resque/tasks'
load "tasks/load.rake"
load "tasks/specialties.rake"

task :environment do
  require 'active_record'
  Bundler.require :default
  require_relative 'environment'
end

task 'resque:setup' => :environment