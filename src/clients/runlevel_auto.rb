# encoding: utf-8

# File:	clients/runlevel_auto.ycp
# Package:	Configuration of Runlevel
# Summary:	Client for autoinstallation
# Authors:	nashif@suse.de
#
# $Id$
#
# This is a client for autoinstallation. It takes its arguments,
# goes through the configuration and return the setting.
# Does not do any changes to the configuration.

# @param function to execute
# @param map/list of RunlevelEd settings
# @return [Hash] edited settings, Summary or boolean on success depending on called function
# @example map mm = $[ "FAIL_DELAY" : "77" ];
# @example map ret = WFM::CallFunction ("RunlevelEd_auto", [ "Summary", mm ]);
module Yast
  class RunlevelAutoClient < Client
    def main
      Yast.import "UI"
      textdomain "runlevel"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Runlevel auto started")

      Yast.import "RunlevelEd"
      Yast.import "Progress"
      Yast.import "Wizard"
      Yast.import "Sequencer"

      Yast.include self, "runlevel/wizard.rb"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)


      RunlevelEd.Init
      # We take data from underlying system
      # RunlevelEd::Read ();


      # Import Data
      if @func == "Import"
        @po = Progress.set(false)
        RunlevelEd.Read
        @ret = RunlevelEd.Import(@param)
        Progress.set(@po)
      # Create a  summary
      elsif @func == "Summary"
        @ret = RunlevelEd.Summary
      # Reset configuration
      elsif @func == "Reset"
        RunlevelEd.Import({})
        @ret = {}
      # Change configuration (run AutoSequence)
      elsif @func == "Change"
        if !RunlevelEd.GetModified
          RunlevelEd.runlevels = Convert.convert(
            SCR.Read(path(".init.scripts.runlevel_list")),
            :from => "any",
            :to   => "list <string>"
          )
          if 0 == Builtins.size(RunlevelEd.runlevels)
            RunlevelEd.runlevels = ["0", "1", "2", "3", "4", "5", "6", "S"]
          end

          #..
          RunlevelEd.default_runlevel = Convert.to_string(
            SCR.Read(path(".init.scripts.default_runlevel"))
          )
        end
        @ret = RunlevelAutoSequence()
      # Read Configuration
      elsif @func == "Read"
        @po = Progress.set(false)
        @ret = RunlevelEd.Read
        Progress.set(@po)
      # Return actual state
      elsif @func == "Export"
        @ret = RunlevelEd.Export
      elsif @func == "Packages"
        @ret = {}
      # Write givven settings
      elsif @func == "Write"
        @po = Progress.set(false)
        @ret = RunlevelEd.Write
        Progress.set(@po)
      elsif @func == "SetModified"
        @ret = RunlevelEd.SetModified
      elsif @func == "GetModified"
        @ret = RunlevelEd.GetModified
      else
        Builtins.y2error("Unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("Runlevel auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret) 

      # EOF
    end
  end
end

Yast::RunlevelAutoClient.new.main
