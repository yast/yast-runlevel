# encoding: utf-8

# File:	runlevel.ycp
# Module:	System Services (Runlevel) (formerly known as Runlevel Editor)
# Summary:	Main File
# Authors:	Martin Lazar <mlazar@suse.cz>, 2004
#
# $Id$
#
module Yast
  class RunlevelClient < Client
    def main
      Yast.import "UI"

      textdomain "runlevel"

      Yast.import "RunlevelEd"
      Yast.import "CommandLine"

      Yast.include self, "runlevel/wizard.rb"

      @cmdline = {
        "id"         => "runlevel",
        # translators: command line help text for runlevel module
        "help"       => _(
          "Configuration of system services (runlevel)"
        ),
        "guihandler" => fun_ref(method(:RunlevelSequence), "symbol ()"),
        "initialize" => fun_ref(RunlevelEd.method(:Read), "boolean ()"),
        "finish"     => fun_ref(RunlevelEd.method(:Write), "boolean ()"),
        "actions"    => {
          "summary" => {
            # translators: command line help text for "summary" action
            "help"    => _(
              "Show a list of current system service status"
            ),
            "handler" => fun_ref(
              method(:SummaryHandler),
              "boolean (map <string, string>)"
            )
          },
          "add"     => {
            # translators: command line help text for "add" action
            "help"    => _(
              "Enable the service"
            ),
            "handler" => fun_ref(
              method(:AddHandler),
              "boolean (map <string, string>)"
            )
          },
          "delete"  => {
            # translators: command line help text for "delete" action
            "help"    => _(
              "Disable the service"
            ),
            "handler" => fun_ref(
              method(:DeleteHandler),
              "boolean (map <string, string>)"
            )
          },
          "set"     => {
            # translators: command line help text for "set" action
            "help"    => _(
              "Set default runlevel after boot"
            ),
            "handler" => fun_ref(
              method(:SetHandler),
              "boolean (map <string, string>)"
            )
          }
        },
        "options"    => {
          "runlevel"  => {
            # translators: command line help text for "runlevel" option
            "help"     => _(
              "Specify default runlevel"
            ),
            "type"     => "enum",
            "typespec" => ["2", "3", "5"]
          },
          "runlevels" => {
            # translators: command line help text for "runlevels" option
            "help" => _(
              "Comma separated list of runlevels"
            ),
            "type" => "string"
          },
          "service"   => {
            # translators: command line help text for "service" option
            "help" => _(
              "Comma separated service names"
            ),
            "type" => "string"
          },
          "defaults"  => {
            # translators: command line help text for "defaults" option
            "help" => _(
              "List default runlevels instead of current"
            ),
            "type" => ""
          }
        },
        "mappings"   => {
          "summary" => ["service", "defaults"],
          "add"     => ["service", "runlevels"],
          "delete"  => ["service", "runlevels"],
          "set"     => ["runlevel"]
        }
      }

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("System service (runlevel) started")

      RunlevelEd.Init
      @ret = CommandLine.Run(@cmdline)

      Builtins.y2milestone("System service (runlevel) finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)
    end

    def AddHandler(opts)
      opts = deep_copy(opts)
      return false if nil == CommandLine.UniqueOption(opts, ["service"])
      rls = nil
      if Ops.get(opts, "runlevels") != nil
        rls = Builtins.splitstring(Ops.get(opts, "runlevels", ""), ",")
      end
      services = Builtins.splitstring(Ops.get(opts, "service", ""), ",")
      Builtins.foreach(services) do |service|
        ierr = RunlevelEd.ServiceInstall(service, rls)
        if ierr == 1
          CommandLine.Print(
            Builtins.sformat(_("Error: service '%1' not found."), service)
          )
        end
      end
      true
    end

    def DeleteHandler(opts)
      opts = deep_copy(opts)
      return false if nil == CommandLine.UniqueOption(opts, ["service"])
      rls = nil
      if Ops.get(opts, "runlevels") != nil
        rls = Builtins.splitstring(Ops.get(opts, "runlevels", ""), ",")
      end
      services = Builtins.splitstring(Ops.get(opts, "service", ""), ",")
      Builtins.foreach(services) do |service|
        RunlevelEd.ServiceRemove(service, rls)
      end
      true
    end

    def SetHandler(opts)
      opts = deep_copy(opts)
      return false if nil == CommandLine.UniqueOption(opts, ["runlevel"])
      RunlevelEd.SetDefaultRunlevel(Ops.get(opts, "runlevel", "5"))
      true
    end

    def CommandLineTableDump(table)
      table = deep_copy(table)
      columns = 0
      len = []
      totallen = 0
      c = 0
      Builtins.foreach(table) do |l|
        columns = Ops.greater_than(Builtins.size(l), columns) ?
          Builtins.size(l) :
          columns
        c = 0
        while Ops.less_than(c, Builtins.size(l))
          if Ops.get(l, c) != nil
            Ops.set(
              len,
              c,
              Ops.greater_than(
                Builtins.size(Ops.get_string(l, c, "")),
                Ops.get(len, c, 0)
              ) ?
                Builtins.size(Ops.get_string(l, c, "")) :
                Ops.get(len, c, 0)
            )
          end
          c = Ops.add(c, 1)
        end
      end
      c = 0
      while Ops.less_than(c, columns)
        totallen = Ops.add(Ops.add(totallen, Ops.get(len, c, 0)), 3)
        c = Ops.add(c, 1)
      end
      if Ops.greater_or_equal(totallen, 80)
        Ops.set(
          len,
          Ops.subtract(columns, 1),
          Ops.subtract(
            80,
            Ops.subtract(totallen, Ops.get(len, Ops.subtract(columns, 1), 0))
          )
        )
        if Ops.less_than(Ops.get(len, Ops.subtract(columns, 1), 0), 3)
          Ops.set(len, Ops.subtract(columns, 1), 3)
        end
      end
      Builtins.foreach(table) do |l|
        line = ""
        c = 0
        if Ops.greater_than(Builtins.size(l), 0)
          while Ops.less_than(c, columns)
            totallen = Builtins.size(line)
            line = Ops.add(line, Ops.get_string(l, c, ""))
            if Ops.less_than(c, Ops.subtract(columns, 1))
              while Ops.less_than(
                  Builtins.size(line),
                  Ops.add(totallen, Ops.get(len, c, 0))
                )
                line = Ops.add(line, " ")
              end
              line = Ops.add(line, " | ")
            end
            c = Ops.add(c, 1)
          end
        else
          while Ops.less_than(c, columns)
            totallen = Builtins.size(line)
            while Ops.less_than(
                Builtins.size(line),
                Ops.add(totallen, Ops.get(len, c, 0))
              )
              line = Ops.add(line, "-")
            end
            if Ops.less_than(c, Ops.subtract(columns, 1))
              line = Ops.add(line, "-+-")
            end
            c = Ops.add(c, 1)
          end
        end
        CommandLine.Print(line)
      end

      nil
    end

    def SummaryHandler(opts)
      opts = deep_copy(opts)
      service_names = nil
      # translators: table headers
      services = [[_("Service"), _("Runlevels"), _("Description")], []]
      rl = {}
      if Ops.get(opts, "service") != nil
        service_names = Convert.convert(
          Builtins.union(
            [Ops.get(opts, "service", "")],
            RunlevelEd.ServiceDependencies(Ops.get(opts, "service", ""), true)
          ),
          :from => "list",
          :to   => "list <string>"
        )
      else
        service_names = RunlevelEd.GetAvailableServices(true)
        CommandLine.Print(
          Builtins.sformat(
            _("Default Runlevel after Boot: %1"),
            RunlevelEd.GetDefaultRunlevel
          )
        )
        CommandLine.Print(
          Builtins.sformat(
            _("Current Runlevel: %1"),
            RunlevelEd.GetCurrentRunlevel
          )
        )
        CommandLine.Print("")
      end
      Builtins.foreach(service_names) do |service_name|
        description = RunlevelEd.GetServiceShortDescription(service_name)
        if description == nil || Builtins.size(description) == 0
          description = RunlevelEd.GetServiceDescription(service_name)
          if Builtins.findfirstof(description, "\n") != nil
            description = Builtins.substring(
              description,
              0,
              Builtins.findfirstof(description, "\n")
            )
          end
        end
        runlevels = []
        if Ops.get(opts, "defaults") != nil
          runlevels = RunlevelEd.GetServiceDefaultStartRunlevels(service_name)
        else
          runlevels = RunlevelEd.GetServiceCurrentStartRunlevels(service_name)
        end
        Builtins.foreach(runlevels) { |r| Ops.set(rl, r, true) }
        services = Builtins.add(
          services,
          [service_name, runlevels, description]
        )
      end
      c = 0
      while Ops.less_than(c, Builtins.size(services))
        if Ops.get(services, [c, 1]) != nil &&
            Ops.is_list?(Ops.get(services, [c, 1]))
          rll = []
          Builtins.foreach(rl) do |r, l|
            rll = Builtins.add(
              rll,
              Builtins.contains(Ops.get_list(services, [c, 1], []), r) ? r : " "
            )
          end
          Ops.set(services, [c, 1], Builtins.mergestring(rll, " "))
        end
        c = Ops.add(c, 1)
      end
      CommandLineTableDump(services)

      nil
    end
  end
end

Yast::RunlevelClient.new.main
