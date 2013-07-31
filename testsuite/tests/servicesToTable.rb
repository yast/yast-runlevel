# encoding: utf-8

# test for servicesToTable
module Yast
  class ServicesToTableClient < Client
    def main
      Yast.import "UI"
      # testedfiles: ui.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"

      @READ = { "target" => { "size" => -1 } }
      TESTSUITE_INIT([@READ, {}, {}], nil)

      Yast.import "RunlevelEd"
      Yast.include self, "runlevel/ui.rb"

      RunlevelEd.runlevels = ["S", "0", "1", "2", "3", "5", "6"]
      RunlevelEd.services = {}

      RunlevelEd.services = {
        "a" => { "dirty" => false, "start" => ["1", "2", "3", "4"] },
        "b" => { "dirty" => false, "start" => ["1", "2"] }
      }
      DUMP(servicesToTable(:complex))

      RunlevelEd.services = {
        "a" => { "dirty" => true, "start" => ["1", "2", "3"] },
        "b" => { "dirty" => true, "start" => ["1", "2", "3"] }
      }
      DUMP(servicesToTable(:complex))

      RunlevelEd.services = {
        "a" => {
          "dirty"    => true,
          "start"    => ["S", "0", "1"],
          "defstart" => ["1", "2", "S", "B"]
        },
        "b" => {
          "dirty"    => true,
          "start"    => ["2", "3", "4", "6", "b"],
          "defstart" => ["1", "2", "S", "b"]
        }
      }
      DUMP(servicesToTable(:complex))

      nil
    end
  end
end

Yast::ServicesToTableClient.new.main
