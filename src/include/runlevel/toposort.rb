# encoding: utf-8

# File:
#   toposort.ycp
#
# Module:
#   System Services (Runlevel) (formerly known as Runlevel Editor)
#
# Summary:
#   Topological sorting for script dependencies
#
# Authors:
#   Martin Vidner <mvidner@suse.cz>
#
# $Id$
module Yast
  module RunlevelToposortInclude
    # Topologically sort a directed acyclic graph, ie. linearize a
    # partial ordering.
    # (what if the graph is a multigraph??)
    # @param [Hash{String => Array<String>}] g A DAG as a map:
    #  nodes are keys, values are lists of nodes that are reached
    #  by an edge from the respective key.
    # @return [out, rest]<br>
    #  out: a list containing the keys of the map in topological order<br>
    #  rest: a list, empty if the graph was acyclic, otherwise it is
    #   a superset of the nodes forming the cycle
    #   and "out" is a partial result
    def TopologicalSort(g)
      g = deep_copy(g)
      out = []
      in_degree = Builtins.mapmap(g) { |vertex, targets| { vertex => 0 } }
      Builtins.foreach(g) { |vertex, targets| Builtins.foreach(targets) do |target|
        Ops.set(in_degree, target, Ops.add(Ops.get(in_degree, target, 0), 1))
      end }

      # cycle
      while Ops.greater_than(Builtins.size(in_degree), 0)
        # get the vertices that can go next because they have zero in degree
        next_m = Builtins.filter(in_degree) { |vertex, d| d == 0 }
        if Builtins.size(next_m) == 0
          # the graph is cyclic!
          break
        end
        Builtins.foreach(next_m) do |vertex, dummy|
          Ops.set(out, Builtins.size(out), vertex)
        end
        # remove the vertices
        in_degree = Builtins.filter(in_degree) { |vertex, d| d != 0 }
        # remove the edges that were leading from them
        Builtins.foreach(next_m) do |vertex, dummy|
          Builtins.foreach(Ops.get(g, vertex, [])) do |target|
            Ops.set(
              in_degree,
              target,
              Ops.subtract(Ops.get(in_degree, target, 0), 1)
            )
          end
        end
      end

      rest = Builtins.maplist(in_degree) { |k, v| k } #mapkeys
      if Ops.greater_than(Builtins.size(rest), 0)
        Builtins.y2error(
          "Cyclic subgraph found, remainder has %1 nodes: %2",
          Builtins.size(rest),
          rest
        )
      end
      [out, rest]
    end

    # Make a subgraph of g, starting at start
    # @param [Hash{String => Array<String>}] g A directed acyclic graph as a map:
    #  nodes are keys, values are lists of nodes that are reached
    #  by an edge from the respective key.
    # @param [String] start starting node
    # @return the reachable subgraph
    def ReachableSubgraph(g, start)
      g = deep_copy(g)
      # a breadth-first search
      result = {}
      # seen and next_layer are sets, realized as maps with dummy values
      seen = {}
      next_layer = { start => true }
      begin
        current_layer = deep_copy(next_layer)
        next_layer = {}
        Builtins.foreach(current_layer) do |node, dummy|
          # action: add the node and edges
          Ops.set(result, node, Ops.get(g, node, []))
          # next
          Ops.set(seen, node, true)
          # targets from this node.
          # filter the ones already seen (including itself)
          targets = Builtins.filter(Ops.get(g, node, [])) do |target|
            !Builtins.haskey(seen, target)
          end
          Builtins.foreach(targets) do |target|
            Ops.set(next_layer, target, true)
          end
        end
      end while Ops.greater_than(Builtins.size(next_layer), 0)
      deep_copy(result)
    end

    # Reverse edges of an oriented graph
    # @param [Hash{String => Array<String>}] g a graph
    # @return reversed graph
    def ReverseGraph(g)
      g = deep_copy(g)
      elist = []
      # initialize, otherwise we miss nodes with zero in-degree
      rev = Builtins.mapmap(g) { |node, dummy| { node => [] } }
      Builtins.foreach(g) { |source, targets| Builtins.foreach(targets) do |target|
        Ops.set(rev, target, Builtins.add(Ops.get(rev, target, elist), source))
      end }
      deep_copy(rev)
    end
  end
end
