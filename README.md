# MCollective Application: Playbook

This project is the result of a few minutes idle thought about what was missing
in MCollective for making it truly useful after being set up. The first thing
missing in MCollective is the ability to set up multi-phase orchestrated actions.

## Basics

Run the `mco-playbook` script with the first argument being the path to a YAML
playbook file.

```
./mco-playbook.rb example.yaml
```

## Playbooks

First, create a playbook. Playbooks are YAML files with sequences of tasks to
run and filters, or target hosts to run them on.

```yaml
- name: "Example task"
```

Each task defines a name, and a filter. The name is purely cosmetic, but will
be printed when the task is running, and the filter defines an MCollective
filter the task will use.

Filters can be for identity, fact, class, or compound. Each type of filter is a
key in the filters hash, and can be a single string or an array. Filters can be
as simple or as complex as necessary. An example using all types of filters is
shown below.

```yaml
- name: "Example task"
  filter:
    identity:
      - centos65a
      - centos65b
    class: profile::webserver
    compound: "profile::webserver and osfamily=RedHat"
    fact: "osfamily=RedHat"
```

After name and filter, a task can either define an `agent` and `action` or
start a `foreach_node`. An action is simple: call the a specified RPC agent and
action (and optionally, parameters) against nodes matching the current filter.
The calls will be performed at the maximum allowable concurrency given
MColletive's batch settings.

```yaml
- name: "Example task"
- name: "Example task"
  filter:
    identity: master
  agent: puppet
  action: runonce
  parameters:
    noop: true
```
 
A `foreach_node`, on the other hand, will step through the nodes matching the
current filter, and using a single-node filter apply a nested set of tasks.

```yaml
- name: "Example task"
  filter:
    class: profile::webserver
  foreach_node:
    tasks:
      - name: "first subtask"
        agent: rpcutil
        action: ping
      - name: "second subtask"
        agent: rpcutil
        action: ping
```

Note that through the `foreach_node` mechanism, a task might contain subtasks.
While the subtasks will default to their parent filter (the foreach_node filter
being set to a single node from its parent filter), each subtask can define and
use its own unrelated filter. This allows sequencing such as iterating over a
collection of application servers, removing each from a load balancer pool,
updating the application, and addding it back to the pool before moving on to
perform the same action on the next application server.

```yaml
    - filter: &load_balancer
        identity: lb.example.com

    - name: "Example task"
      filter:
        class: profile::webserver
      foreach_node:
        tasks:
          - name: "remove from load balancer"
            filter: *load_balancer
            agent: haproxy
            action: remove_from_pool
            parameters:
              pool: "app"
              member: "{{ node }}"
          - name: "update app"
            agent: shell
            action: run
            parameters:
              command: "/some/command --flags argument"
          - name: "add back to load balancer"
            filter: *load_balancer
            agent: haproxy
            action: add_to_pool
            parameters:
              pool: "app"
              member: "{{ node }}"

    - name: "Example follow-up task"
      filter:
        class: profile::webserver
      tasks:
        - name: "run puppet"
          agent: puppet
          action: runonce
        - name: "something else"
          agent: rpcutil
          action: ping
```

## Limitations

A critical feature not yet implemented is something like a `on_failure` option,
which could be used to abort a playbook run if a specified failure condition is
met. Failure conditions might be any node failing, a percentage of nodes
failing, or other.

It would make sense to support other MCollective options inline. This is
primarily a proof-of-concept and the original author may or may not ever get
the time and motivation to add in those kinds of optional features. Because
this is an MCollective RPC Client, most options can be passed in via the
regular MCollective flags, though with the proviso that they will apply to all
agent invocations.
