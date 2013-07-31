# encoding: utf-8

# test for Read and related functions
module Yast
  class ServiceDependenciesClient < Client
    def main
      # these are read before testsuite.ycp installs dummy SCR handlers
      @comments = Convert.convert(
        SCR.Read(path(".target.ycp"), "tests/scripts.ycp.out"),
        :from => "any",
        :to   => "map <string, map>"
      )
      @insserv_conf = Convert.to_map(
        SCR.Read(path(".target.ycp"), "tests/insserv_conf.ycp.out")
      )

      # testedfiles: toposort.ycp RunlevelEd.ycp Report.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"
      Yast.import "Progress"
      Yast.import "Report"

      # assume all the services are enabled
      @all_enabled = Builtins.mapmap(@comments) do |service, descr|
        {
          service => {
            "start" => Ops.get_list(descr, "defstart", []),
            # unused
            "stop"  => Ops.get_list(descr, "defstop", [])
          }
        }
      end
      @all_disabled = Builtins.mapmap(@comments) do |service, descr|
        {
          service => {
            "start" => [],
            # unused
            "stop"  => []
          }
        }
      end

      @READ = {
        "init"   => {
          "insserv_conf" => @insserv_conf,
          "scripts"      => {
            "runlevel_list"    => ["0", "1", "2", "3", "5", "6", "S"],
            "current_runlevel" => "5",
            "default_runlevel" => "5",
            "comments"         => @comments,
            "runlevels"        => @all_enabled
          }
        },
        "target" => { "size" => -1 }
      }
      TESTSUITE_INIT([@READ, {}, {}], nil)

      Yast.import "RunlevelEd"
      Yast.include self, "runlevel/toposort.rb"

      Progress.off
      Report.DisplayErrors(false, 0)

      DUMP(Builtins.size(@comments))





      TEST(lambda { RunlevelEd.Read }, [@READ], nil)
      DUMP(Builtins.size(RunlevelEd.services))
      DUMP(RunlevelEd.ServiceDependencies("xntpd", true))
      DUMP(RunlevelEd.ServiceDependencies("xntpd", false))
      DUMP(RunlevelEd.ServiceDependencies("portmap", true))
      DUMP(RunlevelEd.ServiceDependencies("portmap", false))

      nil
    end
  end
end

Yast::ServiceDependenciesClient.new.main
