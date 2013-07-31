# encoding: utf-8

# test for RunlevelEd::getRunlevelDescr
module Yast
  class GetRunlevelDescrClient < Client
    def main
      # testedfiles: RunlevelEd.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"

      @READ = { "target" => { "size" => -1 } }
      TESTSUITE_INIT([@READ, {}, {}], nil)

      Yast.import "RunlevelEd"

      DUMP(RunlevelEd.getRunlevelDescr(""))
      DUMP(RunlevelEd.getRunlevelDescr("0"))
      DUMP(RunlevelEd.getRunlevelDescr("1"))
      DUMP(RunlevelEd.getRunlevelDescr("2"))
      DUMP(RunlevelEd.getRunlevelDescr("3"))
      DUMP(RunlevelEd.getRunlevelDescr("4"))
      DUMP(RunlevelEd.getRunlevelDescr("5"))
      DUMP(RunlevelEd.getRunlevelDescr("6"))
      DUMP(RunlevelEd.getRunlevelDescr("7"))

      nil
    end
  end
end

Yast::GetRunlevelDescrClient.new.main
