#!/usr/bin/env ruby

require 'yaml'
require 'mcollective'

include MCollective::RPC

def process_decision(options, filter, vars)
  puts options['name'] if options['name']
  filter = options['filter'] || filter
  case
  when options['foreach_node']
    process_foreach(options['foreach_node'], filter, vars)
  when options['tasks']
    options['tasks'].each do |task|
      process_task(task, filter, vars)
    end
  when options['action']
    process_action(options, filter, vars)
  end
end

def process_foreach(options, filter, vars)
  agent = rpcclient('rpcutil')
  set_filter(agent, filter, vars)
  nodes = agent.discover
  nodes.each do |node|
    options['tasks'].each do |task|
      vars.merge!('node' => node)
      process_decision(task, {:discovery => [node]}, vars)
    end
  end
end

def process_task(options, filter, vars)
  puts options['name'] if options['name']
  case
  when options['foreach_node']
    process_foreach(options['foreach_node'], options['filter'], vars)
  when options['action']
    process_action(options, filter, vars)
  end
end

def process_action(options, filter, vars)
  agent = rpcclient(options['agent'])
  set_filter(agent, options['filter'] || filter, vars)
  if options['parameters']
    parameters = options['parameters'].inject({}) do |result,(k,v)|
      result[k.to_sym] = v.is_a?(String) ? interpolate(v, vars) : v
      result
    end
  else
    parameters = nil
  end

  nodes = agent.discover
  puts "Running task: #{options['name']}"
  puts "Nodes: #{nodes.inspect}"
  printrpc agent.method_missing(options['action'], parameters)
  agent.disconnect
end

def set_filter(agent, filters, vars)
  agent.reset
  if filters[:discovery]
    agent.discover({:nodes => filters[:discovery]})
  else
    ['identity', 'fact', 'class', 'compound'].each do |kind|
      next unless filters[kind]
      add_filter = agent.method("#{kind}_filter".to_sym)
      if filters[kind].is_a?(String)
        add_filter.call(interpolate(filters[kind], vars))
      else
        filters[kind].each do |filter|
          add_filter.call(interpolate(filter, vars))
        end
      end
    end
  end
  agent
end

def interpolate(string, vars)
  string.gsub(/{{ (\w+) }}/) { vars[$1] }
end

playbook = YAML.load(File.read(ARGV[0]))
nil_filter = {'filter' => {:discovery => []}}
empty_vars = {}
playbook.each do |set|
  process_decision(set, nil_filter, empty_vars)
end
