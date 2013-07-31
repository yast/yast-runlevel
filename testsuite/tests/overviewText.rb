# encoding: utf-8

# tests overviewText
module Yast
  class OverviewTextClient < Client
    def main
      Yast.import "UI"
      # testedfiles: ui.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"

      @READ = { "target" => { "size" => -1 } }
      TESTSUITE_INIT([@READ, {}, {}], nil)

      Yast.import "RunlevelEd"
      Yast.include self, "runlevel/ui.rb"

      RunlevelEd.current = "3"
      RunlevelEd.services = {
        "a" => { "start" => ["0", "3"], "started" => 0 },
        "b" => { "start" => ["0", "4"], "started" => 0 },
        "c" => { "start" => ["0", "3"], "started" => 0 },
        "d" => { "start" => ["0", "4"], "started" => 0 },
        "e" => { "start" => ["0", "3"], "started" => 1 },
        "f" => { "start" => ["0", "4"], "started" => 1 },
        "g" => { "start" => ["0", "3"], "started" => 1 },
        "h" => { "start" => ["0", "4"], "started" => 2 }
      }
      @s = overviewText
      @spl = Builtins.splitstring(@s, "\n")
      DUMP(@spl)

      nil
    end
  end
end

Yast::OverviewTextClient.new.main
