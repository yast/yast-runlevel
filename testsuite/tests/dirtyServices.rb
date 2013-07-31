# encoding: utf-8

# YaST2 test case for runlevel editor
#
# tests function dirtyServices
module Yast
  class DirtyServicesClient < Client
    def main
      # testedfiles: RunlevelEd.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"

      @READ = { "target" => { "size" => -1 } }
      TESTSUITE_INIT([@READ, {}, {}], nil)

      Yast.import "RunlevelEd"

      RunlevelEd.services = { "a" => {}, "b" => { "start" => ["1"] } }
      DUMP(RunlevelEd.isDirty)
      RunlevelEd.services = {
        "a" => { "dirty" => true },
        "b" => { "start" => ["1"] }
      }
      DUMP(RunlevelEd.isDirty)
      RunlevelEd.services = {
        "a" => { "dirty" => false },
        "b" => { "start" => ["1"], "dirty" => true }
      }
      DUMP(RunlevelEd.isDirty)

      nil
    end
  end
end

Yast::DirtyServicesClient.new.main
