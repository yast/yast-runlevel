# encoding: utf-8

# tests for FilterEnableDisable{,Set} and related functions
module Yast
  class FiltersClient < Client
    def main
      # testedfiles: RunlevelEd.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"

      @READ = { "target" => { "size" => -1 } }
      TESTSUITE_INIT([@READ, {}, {}], nil)

      Yast.import "RunlevelEd"

      RunlevelEd.services = {
        "normal"       => { "start" => ["3", "5"], "defstart" => ["3", "5"] },
        "inactive"     => { "start" => [], "defstart" => ["3", "5"] },
        "justboot"     => { "start" => ["B"], "defstart" => ["B"] },
        "inactiveboot" => { "start" => [], "defstart" => ["B"] }
      }
      @svcs = Builtins.maplist(RunlevelEd.services) { |name, data| name }

      DUMP("enable")
      DUMP(@svcs)
      #args: svcs, rls, enable, init_time, run_time
      TEST(lambda do
        RunlevelEd.FilterAlreadyDoneServices(@svcs, ["4"], true, true, false)
      end, [], nil)
      TEST(lambda do
        RunlevelEd.FilterAlreadyDoneServices(@svcs, ["5"], true, true, false)
      end, [], nil)
      TEST(lambda do
        RunlevelEd.FilterAlreadyDoneServices(
          @svcs,
          ["4", "5"],
          true,
          true,
          false
        )
      end, [], nil)

      # it does not make sense to disable a boot service automatically.
      # it would mean it requires a non-boot service, ie. broken service design
      @svcs = Builtins.filter(@svcs) do |s|
        Ops.get_list(RunlevelEd.services, [s, "defstart"], []) != ["B"]
      end

      DUMP("disable")
      DUMP(@svcs)
      TEST(lambda do
        RunlevelEd.FilterAlreadyDoneServices(@svcs, ["4"], false, true, false)
      end, [], nil)
      TEST(lambda do
        RunlevelEd.FilterAlreadyDoneServices(@svcs, ["5"], false, true, false)
      end, [], nil)
      # not implemented, will fail
      TEST(lambda do
        RunlevelEd.FilterAlreadyDoneServices(
          @svcs,
          ["4", "5"],
          false,
          true,
          false
        )
      end, [], nil)
      TEST(lambda do
        RunlevelEd.FilterAlreadyDoneServices(@svcs, nil, false, true, false)
      end, [], nil)

      nil
    end
  end
end

Yast::FiltersClient.new.main
