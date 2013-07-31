# encoding: utf-8

# test for getDefaultPicker
module Yast
  class GetDefaultPickerClient < Client
    def main
      # testedfiles: ui.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"

      @READ = { "target" => { "size" => -1 } }
      TESTSUITE_INIT([@READ, {}, {}], nil)

      Yast.import "RunlevelEd"

      RunlevelEd.runlevels = ["S", "0", "1", "2", "3", "4", "5", "6"]
      RunlevelEd.default_runlevel = "3"
      DUMP(RunlevelEd.getDefaultPicker(:complex))

      RunlevelEd.runlevels = ["1", "2", "7", "8"]
      RunlevelEd.default_runlevel = "2"
      DUMP(RunlevelEd.getDefaultPicker(:complex))

      RunlevelEd.runlevels = ["1", "2", "7", "8"]
      RunlevelEd.default_runlevel = "3"
      DUMP(RunlevelEd.getDefaultPicker(:auto))

      nil
    end
  end
end

Yast::GetDefaultPickerClient.new.main
