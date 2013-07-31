# encoding: utf-8

# tests formatLine
module Yast
  class FormatLineClient < Client
    def main
      Yast.import "UI"
      # testedfiles: ui.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"

      @READ = { "target" => { "size" => -1 } }
      TESTSUITE_INIT([@READ, {}, {}], nil)

      Yast.include self, "runlevel/ui.rb"

      @s = ""
      @splited = []

      @s = formatLine(["a"], 15)
      @splited = Builtins.splitstring(@s, "\n")
      DUMP(@splited)

      @s = formatLine(["a", "b", "c", "d", "e"], 15)
      @splited = Builtins.splitstring(@s, "\n")
      DUMP(@splited)

      @s = formatLine(
        ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l"],
        15
      )
      @splited = Builtins.splitstring(@s, "\n")
      DUMP(@splited)

      nil
    end
  end
end

Yast::FormatLineClient.new.main
