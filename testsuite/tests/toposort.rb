# encoding: utf-8

# test for TopologicalSort
module Yast
  class ToposortClient < Client
    def main
      # testedfiles: toposort.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"
      Yast.include self, "runlevel/toposort.rb"

      DUMP("TopologicalSort")

      @g_empty = {}
      DUMP(TopologicalSort(@g_empty))

      @g_loop = { "v1" => ["v1"] }
      DUMP(TopologicalSort(@g_loop))

      @g = {
        "v1"  => ["v2", "v3"],
        "v2"  => ["v3", "v4"],
        "v3"  => ["v6"],
        "v4"  => ["v6"],
        "v5"  => ["v4"],
        "v6"  => [],
        "v7"  => ["v6"],
        "v8"  => ["v9"],
        "v9"  => [],
        "v10" => []
      }
      DUMP(TopologicalSort(@g))

      DUMP("ReachableSubgraph")
      DUMP(ReachableSubgraph(@g, "v1"))

      DUMP("ReverseGraph")
      DUMP(ReverseGraph(@g))

      nil
    end
  end
end

Yast::ToposortClient.new.main
