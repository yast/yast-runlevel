# encoding: utf-8

# YaST2 test case for runlevel editor
#
# tests function isDisabled
module Yast
  class IsDisabledClient < Client
    def main
      # testedfiles: RunlevelEd.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"

      @READ = { "target" => { "size" => -1 } }

      @EXECUTE = { "target" => { "bash" => 3 } }

      TESTSUITE_INIT([@READ, {}, @EXECUTE], nil)

      Yast.import "RunlevelEd"

      DUMP(RunlevelEd.isDisabled(""))
      DUMP(RunlevelEd.isDisabled("service"))
      DUMP(RunlevelEd.isDisabled("another-service"))
      DUMP(RunlevelEd.isDisabled("yet-another-service"))

      nil
    end
  end
end

Yast::IsDisabledClient.new.main
