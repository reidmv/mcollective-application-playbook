#!/usr/bin/env ruby

require 'yaml'
require 'mcollective'

include MCollective::RPC

playbook = YAML.load(File.read(ARGV[0]))

playbook.each do |set|
  filter = set['filter']
  set['tasks'].each do |task|
    mc = rpcclient(task['agent'])
    mc.reset
    mc.identity_filter filter['identity'] if filter['identity']
    mc.class_filter filter['class'] if filter['class']
    mc.compound_filter filter['compound'] if filter['compound']

    parameters = task['parameters'].inject({}) do |result,(k,v)|
      result[k.to_sym] = v
      result
    end

    mc.method_missing(task['action'], parameters)
  end
end
