# encoding: utf-8

# YaST2 test case for runlevel editor
#
# tests function saveServices
module Yast
  class SaveServicesClient < Client
    def main
      # testedfiles: RunlevelEd.ycp Service.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"

      @READ = {
        "init"   => {
          "scripts" => {
            "exists"           => true,
            "default_runlevel" => "5",
            "current_runlevel" => "5"
          }
        },
        "target" => { "stat" => { "isreg" => true }, "size" => 0 }
      }
      TESTSUITE_INIT([@READ, {}, {}], nil)

      Yast.import "RunlevelEd"
      Yast.import "Progress"

      Progress.off


      @EXEC = {
        "target" => {
          "bash_output" => { "exit" => 0, "stdout" => "", "stderr" => "" }
        }
      }

      TEST(lambda { RunlevelEd.Write }, [@READ, {}, @EXEC], 0)

      RunlevelEd.services = {
        "a" => { "dirty" => false, "start" => ["1", "2", "3"] },
        "b" => { "dirty" => false, "start" => ["1", "2", "3"] }
      }
      TEST(lambda { RunlevelEd.Write }, [@READ, {}, @EXEC], 0)

      RunlevelEd.services = {
        "a" => { "dirty" => true, "start" => ["1", "2", "3"] },
        "b" => { "dirty" => true, "start" => ["1", "2", "3"] }
      }
      TEST(lambda { RunlevelEd.Write }, [@READ, {}, @EXEC], 0)

      RunlevelEd.services = {
        "a" => {
          "dirty"    => true,
          "start"    => ["1", "2", "3"],
          "defstart" => ["1", "2", "S", "B"]
        },
        "b" => {
          "dirty"    => true,
          "start"    => ["1", "2", "3"],
          "defstart" => ["1", "2", "S", "b"]
        }
      }
      TEST(lambda { RunlevelEd.Write }, [@READ, {}, @EXEC], 0)

      TEST(lambda { RunlevelEd.Write }, [@READ, {}, @EXEC], 0)

      RunlevelEd.services = {
        "a" => { "dirty" => true, "start" => [], "defstart" => ["1", "2", "S"] },
        "b" => { "dirty" => true, "start" => [], "defstart" => ["1", "2", "S"] }
      }
      TEST(lambda { RunlevelEd.Write }, [@READ, {}, @EXEC], 0)

      RunlevelEd.services = {
        "nfsserver" => {
          "dirty"    => false,
          "start"    => ["1"],
          "defstart" => ["1", "2", "S"],
          "reqstart" => ["portmap"]
        },
        "portmap"   => {
          "dirty"    => false,
          "start"    => [],
          "defstart" => ["1", "2", "S"]
        }
      }
      TEST(lambda { RunlevelEd.Write }, [@READ, {}, @EXEC], 0)

      RunlevelEd.services = {
        "nfsserver" => {
          "dirty"    => true,
          "start"    => ["1"],
          "defstart" => ["1", "2", "S"],
          "reqstart" => ["portmap"]
        },
        "portmap"   => {
          "dirty"    => false,
          "start"    => [],
          "defstart" => ["1", "2", "S"]
        }
      }
      TEST(lambda { RunlevelEd.Write }, [@READ, {}, @EXEC], 0)
      Progress.on

      nil
    end
  end
end

Yast::SaveServicesClient.new.main
