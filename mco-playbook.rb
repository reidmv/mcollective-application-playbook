#!/usr/bin/env ruby

require 'yaml'

playbook = YAML.load(File.read(ARGV[0]))

playbook.each do |set|
  set['tasks'].each do |task|
    params = task['parameters'].map {|key,value| key.to_s + '=' + value.to_s }
    command = []
    command << 'mco' << 'rpc'
    command << task['agent'] << task['action']
    command << params.join(' ')
    command << set['filter']
    puts command.join(' ')
  end
end
