# encoding: utf-8

# YaST2 test case for runlevel editor
#
# tests function getScripts
# TODO to be replaced by real data when #16706 is resolved
module Yast
  class GetScriptsClient < Client
    def main
      # testedfiles: RunlevelEd.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"

      # outdated, does not matter
      @insserv_conf = {
        "$local_fs"   => ["boot"],
        "$named"      => ["named"],
        "$netdaemons" => ["portmap", "inetd"],
        "$network"    => ["network", "pcmcia", "hotplug"],
        "$remote_fs"  => ["$local_fs", "nfs"],
        "$syslog"     => ["syslog"]
      }

      @READ = {
        "init"   => {
          "insserv_conf" => @insserv_conf,
          "scripts"      => {
            "runlevels"        => {
              "aaa" => { "start" => ["0", "1", "3"], "stop" => ["4", "5", "6"] },
              "bbb" => { "start" => ["0", "1", "2"], "stop" => ["5", "6"] }
            },
            "comments"         => {
              "aaa" => {
                "defstart" => ["0", "1", "3"],
                "defstop"  => ["4", "5", "6"],
                # workaround for the dummy agent.
                "provides" => []
              },
              "bbb" => {
                "defstart" => ["0", "1", "2"],
                "defstop"  => ["5", "6"],
                "provides" => []
              }
            },
            "runlevel_list"    => ["0", "1", "2", "3", "5", "6", "S"],
            "current_runlevel" => "5",
            "default_runlevel" => "5"
          }
        },
        "target" => {
          "stat"   => { "isreg" => true },
          "size"   => 0,
          "string" => ""
        }
      }


      TESTSUITE_INIT([@READ, {}, {}], nil)

      Yast.import "RunlevelEd"

      Yast.import "Progress"

      Progress.off



      TEST(lambda { RunlevelEd.Read }, [@READ], 0)
      DUMP(RunlevelEd.services)

      @READ = {
        "init"   => {
          "insserv_conf" => @insserv_conf,
          "scripts"      => {
            "runlevels"        => {
              "aaa" => { "start" => ["0", "1", "3"], "stop" => ["4", "5", "6"] },
              "ccc" => { "start" => ["0", "1", "2"], "stop" => ["5", "6"] }
            },
            "comments"         => {
              "aaa" => {
                "defstart" => ["0", "1", "3"],
                "defstop"  => ["4", "5", "6"],
                "provides" => []
              },
              "bbb" => {
                "defstart" => ["0", "1", "2"],
                "defstop"  => ["5", "6"],
                "provides" => []
              }
            },
            "runlevel_list"    => ["0", "1", "2", "3", "5", "6", "S"],
            "current_runlevel" => "5",
            "default_runlevel" => "5"
          }
        },
        "target" => {
          "stat"   => { "isreg" => true },
          "size"   => 0,
          "string" => ""
        }
      }

      TEST(lambda { RunlevelEd.Read }, [@READ], 0)
      DUMP(RunlevelEd.services)

      Progress.on

      nil
    end
  end
end

Yast::GetScriptsClient.new.main
