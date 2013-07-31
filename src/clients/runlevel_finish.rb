# encoding: utf-8

# File:
#  runlevel_finish.ycp
#
# Module:
#  Step of base installation finish
#
# Authors:
#  Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
module Yast
  class RunlevelFinishClient < Client
    def main

      textdomain "runlevel"

      Yast.import "Mode"
      Yast.import "RunlevelEd"
      Yast.import "Systemd"
      Yast.import "Directory"

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

      Builtins.y2milestone("starting runlevel_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Info"
        return {
          "steps" => 1,
          # progress step title
          "title" => _("Saving default runlevel..."),
          "when"  => [:installation, :live_installation, :update, :autoinst]
        }
      elsif @func == "Write"
        if !Mode.update
          # see bug #32366 why we need this here
          # and 30028
          # now it is set in the initial proposal
          # Fall back to 3 if we accidentally don't set it there
          # otherwise it would be 0 (#35662)
          set_runlevel(
            RunlevelEd.default_runlevel == "" ?
              3 :
              Builtins.tointeger(RunlevelEd.default_runlevel)
          )
        else
          Builtins.y2milestone("Update mode, no need to set runlevel again...")
        end
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("runlevel_finish finished")
      deep_copy(@ret)
    end

    def set_runlevel(runlevel)
      Builtins.y2milestone("setting default runlevel to %1", runlevel)
      SCR.Write(
        path(".etc.inittab.id"),
        Builtins.sformat("%1:initdefault:", runlevel)
      )
      SCR.Write(path(".etc.inittab"), nil)

      # create a default symlink for systemd if it is installed
      if Systemd.Installed
        Systemd.SetDefaultRunlevel(runlevel)
      else
        Builtins.y2milestone("Systemd is not installed")
      end

      nil
    end
  end
end

Yast::RunlevelFinishClient.new.main
