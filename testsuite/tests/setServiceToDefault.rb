# encoding: utf-8

# test for serServiceToDefault
module Yast
  class SetServiceToDefaultClient < Client
    def main
      Yast.import "UI"
      # testedfiles: ui.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"

      @READ = { "target" => { "size" => -1 } }
      TESTSUITE_INIT([@READ, {}, {}], nil)

      Yast.include self, "runlevel/ui.rb"

      Yast.import "RunlevelEd"

      RunlevelEd.services = {
        "a" => { "start" => ["1", "2"], "defstart" => ["3", "4"] }
      }
      setServiceToDefault("a")
      DUMP(RunlevelEd.services)

      nil
    end
  end
end

Yast::SetServiceToDefaultClient.new.main
