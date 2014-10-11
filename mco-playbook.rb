#!/usr/bin/env ruby

require 'yaml'
require 'mcollective'

include MCollective::RPC

# Determines whether the given element should be treated as an action, a list
# of tasks, or a foreach collection to iterate over. Starts by setting the
# filter (if applicable), and then after making the determination, calls the
# appropriate method.
def process_task(options, filter, vars)
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

# Handles filtering for a collection and then iteratively calling
# process_task() for each element as a single-node filter.
def process_foreach(options, filter, vars)
  agent = rpcclient('rpcutil')
  set_filter(agent, filter, vars)
  nodes = agent.discover
  nodes.each do |node|
    options['tasks'].each do |task|
      vars.merge!('node' => node)
      process_task(task, {:discovery => [node]}, vars)
    end
  end
end

# Sets up an MCollective rpcclient and parses options to determine agent,
# action, and parameters. Performs the RPC call.
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

# Given an rpcagent and a set of filters, configures the agent appropriately.
# Depending on options in the filters hash, the agent may be configured with a
# combination of identity, fact, class, and compound filters, or may be given a
# node or set of nodes as pre-discovery.
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

# Given a string, performs search/replace for interpolation patterns, and
# replaces each variable with one from the accompanying vars array.
def interpolate(string, vars)
  string.gsub(/{{ (\w+) }}/) { vars[$1] }
end

playbook = YAML.load(File.read(ARGV[0]))
nil_filter = {'filter' => {:discovery => []}}
empty_vars = {}
playbook.each do |set|
  process_task(set, nil_filter, empty_vars)
end
