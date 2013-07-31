# encoding: utf-8

# File:
#   RunlevelEd.ycp
# Package:
#   System Services (Runlevel) (formerly known as Runlevel Editor)
# Summary:
#   Data for configuration of services, input and output functions.
#
# Authors:
#   Martin Vidner <mvidner@suse.cz>
#   Petr Blahos <pblahos@suse.cz>
#   Martin Lazar <mlazar@suse.cz>
#   Lukas Ocilka <locilka@suse.com>
#   Ladislav Slezak <lslezak@suse.com>
#
# $Id$
require "yast"

module Yast
  class RunlevelEdClass < Module
    def main
      textdomain "runlevel"

      Yast.import "Service"
      Yast.import "Progress"
      Yast.import "Summary"
      Yast.import "Report"
      Yast.import "CommandLine"
      Yast.import "ProductControl"
      Yast.import "ProductFeatures"
      Yast.import "Systemd"
      Yast.import "Message"
      Yast.import "Mode"

      Yast.include self, "runlevel/toposort.rb"

      # default value defined in control_file->defaults->rle_offer_rulevel_4
      @offer_runlevel_4 = false

      @configuration_already_loaded = false

      @services_proposal_settings = []
      @services_proposal_links = []

      # Proposal parameter: if it changes, we repropose
      @x11_selected = nil

      # Like "requires" but in reverse direction.
      # Used for stopping and disabling services.
      @what_requires = {}

      # A graph where nodes are scripts or system facilities
      # but not normal facilities (ie. provides are solved).
      @requires = {}

      #  * @struct service
      #  * One service is described by such map: <pre>
      # "servicename" : $[
      #     "defstart" : [ "2", "3", "5", ], // Default-Start comment
      #     "defstop"  : [ "0", "1", "6", ], // Default-Stop  comment
      #
      #     // "should" dependencies (+) are filtered by addRequires
      #     "reqstart" : [ "$network", "portmap" ], // Required-Start comment
      #     "reqstop"  : [ "$network", "portmap" ], // Required-Stop  comment
      #
      #     "shortdescription" : "text...",       // Description comment
      #     "description" : "text...",       // Description comment
      #
      #     // which runlevels service is really started/stopped in
      #     // read from /etc/init.d/{rc?,boot}.d/* links
      #     //
      #     // Note that the boot process (init.d/boot.d) is considered
      #     // a "B" runlevel that is implicitly contained in the other runlevels.
      #     // Using
      #     //   list st = services ["boot.local", "start"]:[]
      #     //   contains (st, "3") // DON'T
      #     // results in false but that's probably not what you want.
      #     // Use
      #     //   StartContainsImplicitly (st, "3")
      #     // which tests for "3" and "B".
      #     "start" : [ "3", "5", ],
      #     "stop"  : [ "3", "5", ],
      #
      #     "started" : 0, // return from rcservice status (integer)
      #
      #     "dirty" : false, // was the entry changed?
      # ]</pre>

      # List of all services. Each item is a map described above.
      # {#service}
      @services = {}

      # List of all service names.
      # Filled by Read, used to get all services' status.
      @service_list = []

      # Default runlevel (after boot)
      @default_runlevel = ""

      # Backup of default runlevel.
      @default_orig = ""

      # List of all runlevels available in the system.
      @runlevels = []

      # Current runlevel
      @current = nil

      # Dependency solving:
      # ONLY ONE SCRIPT provides a facility in this model.
      # In SuSE packages, the only exception are sendmail and postfix
      # both providing sendmail but they cannot be installed together
      # anyway.
      # atd has Provides: at, so
      #   what_provides["at"] == "atd";
      # Identity is not represented explicitly: ypbind has Provides: ypbind, but
      #   haskey (what_provides, "ypbind") == false;
      @what_provides = {}

      # System facility definitions
      # "should" dependencies (+) are filtered by addRequires
      # /etc/insserv.conf:
      #   system_requires["$network"] == ["network", "+pcmcia", "+hotplug"];
      @system_requires = {}

      # If there's a dependency loop, dependency checking is disabled.
      @dependencies_disabled = false

      # visualization helper

      # A buffer for {#sprint}
      @sprint_buffer = ""

      @already_initialized = false
    end

    # Sets whether runlevel 4 should be supported.
    #
    # @param [Boolean] new_state (true == supported)
    # @see FATE #303798
    def SetRunlevel4Support(new_state)
      if new_state == nil
        Builtins.y2error("Wrong runlevel4 value")
        return
      end

      @offer_runlevel_4 = new_state
      Builtins.y2milestone("Runlevel 4 support set to: %1", @offer_runlevel_4)

      nil
    end

    # Returns whether runlevel 4 is supported in RLEd.
    #
    # @return [Boolean] supported
    def GetRunlevel4Support
      @offer_runlevel_4
    end


    def SystemRunlevels
      @runlevels = Convert.convert(
        SCR.Read(path(".init.scripts.runlevel_list")),
        :from => "any",
        :to   => "list <string>"
      )

      if @runlevels == nil || Builtins.size(@runlevels) == 0
        @runlevels = ["0", "1", "2", "3", "5", "6", "S"]
      end

      if GetRunlevel4Support() && !Builtins.contains(@runlevels, "4")
        Builtins.y2milestone("Adding runlevel 4")
        @runlevels = Builtins.add(@runlevels, "4")
      end

      Builtins.sort(@runlevels)
    end

    # Goes throgh the services map and creates internal map of services dependencies.
    def BuildServicesRequirements
      buildRequires
      @what_requires = ReverseGraph(@requires)

      nil
    end

    # Read settings
    # @return success
    def Read
      # progress caption
      Progress.Simple(
        _("Initializing system services (runlevel). Please wait..."),
        " ",
        7,
        ""
      )
      Progress.NextStep

      @runlevels = SystemRunlevels()
      Progress.NextStep

      @current = GetCurrentRunlevel()
      Progress.NextStep

      # read the default from the current init system (systemd or classic init)
      @default_runlevel = Systemd.Running ?
        Builtins.tostring(Systemd.DefaultRunlevel) :
        Convert.to_string(SCR.Read(path(".init.scripts.default_runlevel")))
      @default_orig = @default_runlevel
      Progress.NextStep

      @system_requires = Convert.convert(
        SCR.Read(path(".init.insserv_conf")),
        :from => "any",
        :to   => "map <string, list <string>>"
      )

      # bnc #435182
      # new key: <interactive>
      @system_requires = Builtins.filter(@system_requires) do |key, val|
        if Builtins.regexpmatch(key, "\\$.+")
          next true
        else
          Builtins.y2warning("Ignoring requirement: %1", key)
          next false
        end
      end

      Progress.NextStep

      details = Convert.to_map(SCR.Read(path(".init.scripts.runlevels")))
      Progress.NextStep
      @services = Convert.convert(
        SCR.Read(path(".init.scripts.comments")),
        :from => "any",
        :to   => "map <string, map>"
      )
      Progress.NextStep
      @services = Builtins.mapmap(@services) do |k, v|
        Builtins.foreach(Ops.get_list(v, "provides", [])) do |f|
          # identity implicit; only the first script provides a facility
          if f != k && !Builtins.haskey(@what_provides, f)
            Ops.set(@what_provides, f, k)
          end
        end
        Ops.set(@service_list, Builtins.size(@service_list), k)
        # play tennis
        second_service = Ops.get_map(details, k, {})
        Ops.set(v, "start", Ops.get_list(second_service, "start", []))
        Ops.set(v, "stop", Ops.get_list(second_service, "stop", []))
        { k => v }
      end

      BuildServicesRequirements()
      Progress.NextStep
      true
    end
    def buildRequires
      Builtins.foreach(@services) do |service, comments|
        addRequires(service, Ops.get_list(comments, "reqstart", []))
      end
      Builtins.foreach(@system_requires) { |sys_f, req| addRequires(sys_f, req) }

      nil
    end
    def addRequires(service, req_facilities)
      req_facilities = deep_copy(req_facilities)
      req_s = Builtins.filter(req_facilities) do |f|
        Builtins.substring(f, 0, 1) != "+"
      end
      req_s = Builtins.maplist(req_s) do |f|
        Ops.get_string(@what_provides, f, f)
      end
      Ops.set(@requires, service, req_s)

      nil
    end


    # Resolve which services need to be enabled/disabled
    # @param [String] service a service
    # @param [Boolean] enable enabling or disabling a service?
    # @return a list of services (excluding itself) required to start
    # a service (enable) or to be stopped because they require the
    # service (disable), ordered by their dependencies. Missing
    # services are included, system facilities excluded.<br>
    # If dependencies are disabled, returns an empty list, as if
    # there were no dependencies.
    def ServiceDependencies(service, enable)
      return [] if @dependencies_disabled
      # make a dependency subgraph
      s_req = ReachableSubgraph(enable ? @requires : @what_requires, service)
      Builtins.y2debug("DEPGRAPH %1: %2", service, s_req)
      # sort it
      r = TopologicalSort(s_req)
      sorted = Ops.get_list(r, 0, [])
      rest = Ops.get_list(r, 1, [])
      if Ops.greater_than(Builtins.size(rest), 0)
        # TODO: localize the loop, disable it only locally
        # and say what scripts form it
        Report.Error(
          _(
            "A dependency loop was detected.\nFurther dependency checking will be disabled."
          )
        )
        @dependencies_disabled = true
      end

      # filter system facilities
      sorted = Builtins.filter(sorted) { |f| Builtins.substring(f, 0, 1) != "$" }
      # remove the original service
      sorted = Builtins.remove(sorted, 0)
      # reverse it so that the required services are first
      Convert.convert(reverse(sorted), :from => "list", :to => "list <string>")
    end
    def reverse(l)
      l = deep_copy(l)
      return nil if l == nil
      result = []
      Builtins.foreach(l) { |item| result = Builtins.prepend(result, item) }
      deep_copy(result)
    end





    # Gets a list of dependent services and a target state they
    # should be in. Filters out those that are already in the target
    # state.
    # If both init_time and run_time are on, a conjunction is needed.
    # @param [Array<String>] svcs	dependent services
    # @param [Array<String>] rls	used for init_time
    # @param [Boolean] enable	on/off:
    # @param [Boolean] init_time enable/disable
    # @param [Boolean] run_time  start/stop
    def FilterAlreadyDoneServices(svcs, rls, enable, init_time, run_time)
      svcs = deep_copy(svcs)
      rls = deep_copy(rls)
      # one: exactly one runlevel. nil means (disable) in all runlevels
      one = rls != nil && Builtins.size(rls) == 1
      if init_time && !enable && rls != nil && !one
        # should not happen
        Builtins.y2error(
          "Disabling in a nontrivial set of runlevels (%1) not implemented.",
          rls
        )
        return nil
      end
      rl = Ops.get(rls, 0, "")

      Builtins.filter(svcs) do |service|
        all_ok = nil # is the service in the target state?
        # run_time
        run_ok = true
        if run_time
          started = Ops.get_integer(@services, [service, "started"], -1) == 0 ||
            Ops.get_list(
              # boot scripts are always considered to be started,
              # even if they return 4 :(
              @services,
              [service, "defstart"],
              []
            ) ==
              ["B"] ||
            # and while we're at it with kludges,
            # pretend nfs is running (ie. /usr is available)
            # because it reports 3 when no nfs imports are defined :(
            # TODO resolve it better!
            service == "nfs"
          run_ok = started == enable
        end
        # init_time
        init_ok = true
        if init_time
          start = Ops.get_list(@services, [service, "start"], [])

          if one
            init_ok = enable == StartContainsImplicitly(start, rl)
          else
            if enable
              init_ok = ImplicitlySubset(rls, start)
            else
              # rls is nil, we only support disabling
              # in one or all runleves at once
              init_ok = start == []
            end
          end
        end
        # keep it in the list if something needs to be done
        !(init_ok && run_ok)
      end
    end



    # Is a service started in a runlevel, given the list of rulevels
    # it is started in?
    # This looks like a simple contains,
    # but "B" implicitly expands to all runlevels.
    # See also bug #17234.
    # @param [Array<String>] rls runlevels the service is started in
    # @param [String] rl  which runlevel is tested
    # @return should it be running in rl?
    def StartContainsImplicitly(rls, rl)
      rls = deep_copy(rls)
      Builtins.contains(rls, "B") || Builtins.contains(rls, rl)
    end
    def ImplicitlySubset(rls_a, rls_b)
      rls_a = deep_copy(rls_a)
      rls_b = deep_copy(rls_b)
      Builtins.contains(rls_b, "B") || subset(rls_a, rls_b)
    end
    def subset(a, b)
      a = deep_copy(a)
      b = deep_copy(b)
      Ops.less_or_equal(Builtins.size(Builtins.union(a, b)), Builtins.size(b))
    end

    # Set all dirty services as clean and tries to read
    # original "start"/"stop" for them.
    def ClearServices
      @services = Builtins.mapmap(@services) do |k, v|
        if Ops.get_boolean(v, "dirty", false)
          Ops.set(v, "dirty", false)
          r = Convert.to_map(SCR.Read(path(".init.scripts.runlevel"), k))
          r = Ops.get_map(r, k, {})
          Ops.set(v, "start", Ops.get_list(r, "start", []))
          Ops.set(v, "stop", Ops.get_list(r, "stop", []))
        end
        { k => v }
      end

      nil
    end

    # Is a service disabled?
    # Checks whether the default runlevel is in the list of runlevels
    # @param [String] service name to check
    # @return [Boolean] true if service is disabled
    def isDisabled(service)
      !Service.Enabled(service)
    end

    # Check for portmap. Portmap should be started if inetd, nfs,
    # nfsserver, nis, ... is started. This checks the dependency.
    # @return [String] name of the first enabled service that requires portmap
    def CheckPortmap
      if !isDisabled("portmap") # if portmap is enabled, there is no problem
        return nil
      end
      req = nil
      _in = []
      Builtins.foreach(@services) do |k, v|
        if Builtins.contains(Ops.get_list(v, "reqstart", []), "portmap") &&
            Ops.greater_than(Builtins.size(Ops.get_list(v, "start", [])), 0)
          _in = Builtins.union(
            _in,
            Builtins.toset(Ops.get_list(v, "start", []))
          )
          req = k if nil == req
        end
      end
      Ops.greater_than(Builtins.size(_in), 0) ? req : nil
    end

    # Works as List::toset but keeps the given sorting.
    # First occurence of an element always wins.
    def RemoveDuplicates(l)
      l = deep_copy(l)
      new_l = []

      Builtins.foreach(l) do |l_item|
        new_l = Builtins.add(new_l, l_item) if !Builtins.contains(new_l, l_item)
      end

      deep_copy(new_l)
    end

    # Finds all service dependencies of services given as argument
    #
    # @param list <string> list of services
    def ServicesDependencies(services_list)
      services_list = deep_copy(services_list)
      all_needed_services = []

      # Find all the services dependencies first
      Builtins.foreach(services_list) do |service|
        needed_services = ServiceDependencies(service, true)
        if needed_services != nil && needed_services != []
          Builtins.y2milestone(
            "Service dependencies for %1 are: %2",
            service,
            needed_services
          )
          all_needed_services = Convert.convert(
            Builtins.merge(all_needed_services, needed_services),
            :from => "list",
            :to   => "list <string>"
          )
        end
      end

      # It's important that sorting of services is kept,
      # dependencies list represents map of dependencies in 1-D
      Convert.convert(
        RemoveDuplicates(all_needed_services),
        :from => "list",
        :to   => "list <string>"
      )
    end

    def InAutoYast
      Mode.autoinst || Mode.config
    end

    # Returns list of services that were changed during
    # configuration (so-called 'dirty'), boot.* services are excluded.
    def ListOfServicesToStart
      services_to_start = []
      current_runlevel = GetCurrentRunlevel()

      # In AutoYast the current runlevel doesn't matter
      # the imported one (default_runlevel) does.
      current_runlevel = GetDefaultRunlevel() if InAutoYast()

      Builtins.y2milestone("Current runlevel: %1", current_runlevel)

      Builtins.foreach(@services) do |service, details|
        # boot.* services are ignored
        next if Builtins.regexpmatch(service, "^boot..*")
        # these services should not be running now
        if !Builtins.contains(
            Ops.get_list(details, "start", []),
            current_runlevel
          )
          next
        end
        # only changed services
        next if !Ops.get_boolean(details, "dirty", false)
        services_to_start = Builtins.add(services_to_start, service)
      end

      Builtins.y2milestone("Services to start: %1", services_to_start)

      deep_copy(services_to_start)
    end

    # Returns list of runlevels in which the service given as argument
    # should start
    #
    # @param [String] service name
    # @param list <string> list of runlevels
    def StartServiceInRunlevels(service)
      if !Builtins.haskey(@services, service)
        Builtins.y2error("Unknown service %1", service)
        return []
      end

      start_service = Ops.get(@services, service, {})

      # user-defined values
      if Builtins.haskey(start_service, "start")
        return Ops.get_list(start_service, "start", []) 
        # default values
      elsif Builtins.haskey(start_service, "defstart")
        return Ops.get_list(start_service, "defstart", [])
      else
        Builtins.y2error("No 'start' or 'defstart' key in %1", start_service)
        return []
      end
    end

    # Enables and starts services with their dependencies.
    # Already running services are kept untouched.
    #
    # @param list <string> services to start
    def StartServicesWithDependencies(services_list)
      services_list = deep_copy(services_list)
      ret = true

      # given services added to the list of all services
      all_needed_services = Convert.convert(
        Builtins.merge(ServicesDependencies(services_list), services_list),
        :from => "list",
        :to   => "list <string>"
      )

      Builtins.foreach(services_list) do |service|
        runlevels_start = StartServiceInRunlevels(service)
        # Check and enable service
        if Service.Enabled(service) != true &&
            Service.Finetune(service, runlevels_start) != true
          Builtins.y2error("Unable to enable service %1", service)
          Report.Error(Builtins.sformat(_("Cannot enable service %1"), service))
          ret = false
        end
        # All boot.* scripts are skipped
        # See BNC #583773
        if Builtins.regexpmatch(service, "^boot..*")
          Builtins.y2warning("Skipping service %1", service)
          next
        end
        # Check and start service
        if Service.Status(service) == -1
          Builtins.y2error("Service name %1 is unknown", service)
          Report.Error(
            Builtins.sformat(
              _(
                "Unable to start and enable service %1.\nService is not installed."
              ),
              service
            )
          )
          ret = false
        else
          if Service.RunInitScriptWithTimeOut(service, "status") != 0 &&
              Service.RunInitScriptWithTimeOut(service, "start") != 0
            Builtins.y2error("Unable to start service %1", service)
            Report.Error(Message.CannotStartService(service))
            ret = false
          end
        end
      end

      ret
    end

    # Enables/disables all services according to the default settings
    #
    # @param map <string, map> services map
    # @param boolean if progress is used
    # @return [Boolean] if successful
    def AdaptServices(services_list, uses_progress)
      services_list = deep_copy(services_list)
      failed = Builtins.filter(services_list) do |k, v|
        fail = false
        if Ops.get_boolean(v, "dirty", false)
          # progress item, %1 is a service (init script) name
          Progress.Title(Builtins.sformat(_("Service %1"), k)) if uses_progress
          # save!
          start = Ops.get_list(v, "start", [])
          Builtins.y2milestone("Setting %1: %2", k, start)
          # this can also disable some services
          CommandLine.PrintVerbose(
            Builtins.sformat(_("Setting %1: %2"), k, start)
          )
          fail = !Service.Finetune(k, start)
        else
          Builtins.y2milestone("Skipping service %1 (not changed)", k)
          # progress item, %1 is a service (init script) name
          if uses_progress
            Progress.Title(Builtins.sformat(_("Skipping service %1."), k))
          end
        end
        Progress.NextStep if uses_progress
        fail
      end

      Progress.NextStep if uses_progress

      failed_s = Builtins.mergestring(Builtins.maplist(failed) { |k, v| k }, ", ")
      if Ops.greater_than(Builtins.size(failed_s), 0)
        Report.Error(Builtins.sformat(_("Failed services: %1."), failed_s))
        return false
      end

      true
    end

    # Enables services in their default runlevels
    #
    # @param list <string> list of services to enable
    # @return [Boolean] if successful
    def EnableServices(services_list)
      services_list = deep_copy(services_list)
      ret = true

      Builtins.y2milestone("Enabling services %1", services_list)
      Builtins.foreach(services_list) do |service|
        if !Service.Enable(service)
          Report.Error(
            Builtins.sformat(_("Cannot enable service %1."), service)
          )
          ret = false
        end
      end

      ret
    end

    # Save changed services into proper runlevels. Save also changed
    # default runlevel.
    # @return success
    def Write
      prsize = Builtins.size(@services)
      # progress caption
      Progress.Simple(
        _("Saving changes to runlevels."),
        " ",
        Ops.add(prsize, 1),
        ""
      )

      if @default_runlevel != @default_orig
        SCR.Write(path(".init.scripts.default_runlevel"), @default_runlevel)

        # write systemd default (if present) so it works also after switch to systemd
        if Systemd.Installed
          Systemd.SetDefaultRunlevel(Builtins.tointeger(@default_runlevel))
        end
      end

      if @default_runlevel == "4"
        # If not in use, the whole runlevel is commented out!
        Builtins.y2milestone("Runlevel 4 in use!")
        SCR.Execute(
          path(".target.bash"),
          "sed --in-place 's/^\\(#\\)\\(l4:4:wait:\\/etc\\/init.d\\/rc 4\\)/\\2/' /etc/inittab"
        )
      else
        Builtins.y2milestone("Runlevel %1 in use...", @default_runlevel)
        SCR.Execute(
          path(".target.bash"),
          "sed --in-place 's/^\\(l4:4:wait:\\/etc\\/init.d\\/rc 4\\)/#\\1/' /etc/inittab"
        )
      end

      Progress.NextStep
      return false if !AdaptServices(@services, true)

      # All services need to be started at the end by systemd,
      # not here and now. See BNC #769924
      if InAutoYast()
        Builtins.y2milestone(
          "All services will be started at the end, skipping for now..."
        )
        return true
      end

      # Enable and start all services that should be started
      StartServicesWithDependencies(ListOfServicesToStart())
    end

    # Were some settings changed?
    # @return true if yes
    def isDirty
      return true if @default_runlevel != @default_orig

      dirty = false
      Builtins.foreach(@services) do |k, v|
        next if dirty
        dirty = true if Ops.get_boolean(v, "dirty", false)
      end
      dirty
    end

    # Returns true if the settings were modified
    # @return settings were modified
    def GetModified
      isDirty
    end

    # Function sets an internal variable indicating that any
    # settings were modified to "true".
    # Used for autoinst cloning.
    def SetModified
      # Make sure GetModified will return true
      @default_orig = "---" 
      # maybe we should also touch dirty for all services,
      # but that depends on what autoinst Clone really wants

      nil
    end

    # Export user settings.
    # @return user settings:<pre>$[
    #    "services": $[ map of dirty services ],
    #    "default":  the default runlevel, if changed,
    #]</pre>
    def Export
      Builtins.y2debug("services: %1", @services)
      svc = Builtins.filter(@services) do |k, v|
        Ops.get_boolean(v, "dirty", false)
      end
      tmp_services = Builtins.maplist(svc) do |service_name, service_data|
        service_start = Builtins.mergestring(
          Ops.get_list(service_data, "start", []),
          " "
        )
        service_stop = Builtins.mergestring(
          Ops.get_list(service_data, "stop", []),
          " "
        )
        service_map = {}
        Ops.set(service_map, "service_name", service_name)
        if Ops.greater_than(Builtins.size(service_start), 0)
          Ops.set(service_map, "service_start", service_start)
        end
        if Ops.greater_than(Builtins.size(service_stop), 0)
          Ops.set(service_map, "service_stop", service_stop)
        end
        deep_copy(service_map)
      end
      ret = {}
      if Ops.greater_than(Builtins.size(tmp_services), 0)
        ret = { "services" => tmp_services }
      end
      Ops.set(ret, "default", @default_runlevel) if @default_runlevel != ""
      deep_copy(ret)
    end
    # Import user settings
    # @param [Hash] s user settings
    # @see #Export
    # @return success state
    def Import(s)
      s = deep_copy(s)
      @runlevels = Convert.convert(
        SCR.Read(path(".init.scripts.runlevel_list")),
        :from => "any",
        :to   => "list <string>"
      )
      if 0 == Builtins.size(@runlevels)
        if GetRunlevel4Support()
          @runlevels = ["0", "1", "2", "3", "4", "5", "6", "S"]
        else
          @runlevels = ["0", "1", "2", "3", "5", "6", "S"]
        end
      end

      # read the default from the current init system (systemd or classic init)
      @default_runlevel = Systemd.Running ?
        Builtins.tostring(Systemd.DefaultRunlevel) :
        Convert.to_string(SCR.Read(path(".init.scripts.default_runlevel")))
      @default_orig = @default_runlevel

      # and finaly process map being imported
      new = Ops.get_list(s, "services", [])
      tmp_services = Builtins.listmap(new) do |service|
        name = Ops.get_string(service, "service_name", "")
        stop = []
        start = []
        if Builtins.haskey(service, "service_status")
          if Ops.get_string(service, "service_status", "") == "enable"
            info = Service.Info(name)
            Builtins.y2milestone("service info for %1: %2", name, info)
            start = Ops.get_list(info, "defstart", [])
            stop = Ops.get_list(info, "defstop", [])
          elsif Ops.get_string(service, "service_status", "") == "disable"
            start = []
            stop = []
          else
            Builtins.y2error(
              "Unsupported entry: %1 (should be enable/disable)",
              service
            )
          end
        else
          start = Builtins.splitstring(
            Ops.get_string(service, "service_start", ""),
            " "
          )
          stop = Builtins.splitstring(
            Ops.get_string(service, "service_stop", ""),
            " "
          )
        end
        service_map = {}
        if Ops.greater_than(Builtins.size(start), 0)
          Ops.set(service_map, "start", start)
        end
        if Ops.greater_than(Builtins.size(stop), 0)
          Ops.set(service_map, "stop", stop)
        end
        { name => service_map }
      end

      if Ops.greater_than(Builtins.size(tmp_services), 0)
        Builtins.foreach(tmp_services) do |k, v|
          if nil == Ops.get(@services, k)
            Builtins.y2milestone(
              "Service %1 is not installed on target system, adding it by hand.",
              k
            )
          end
          Ops.set(v, "dirty", true)
          Ops.set(@services, k, v)
        end
      else
        @services = {}
      end
      # default
      if Builtins.haskey(s, "default")
        @default_runlevel = Ops.get_string(s, "default", "")
        @default_orig = "---"
      end
      true
    end

    # Returns textual runlevel description.
    # Descriptions are hard-coded in ycp script.
    # @param [String] rl Runlevel to check.
    # @return [String] Description.
    def getRunlevelDescr(rl)
      descr = {
        # descriptions of runlevels. there must be number: description
        # number is runlevel name
        # runlevel description
        "0" => _(
          "0: System halt"
        ),
        # runlevel description
        "1" => _("1: Single user mode"),
        # runlevel description
        "2" => _(
          "2: Local multiuser without remote network"
        ),
        # runlevel description
        "3" => _("3: Full multiuser with network"),
        # runlevel description
        "4" => _("4: User defined"),
        # runlevel description
        "5" => _(
          "5: Full multiuser with network and display manager"
        ),
        # runlevel description
        "6" => _("6: System reboot"),
        # runlevel description
        # internal one: without a number
        ""  => _(
          "Unchanged"
        )
      }
      Ops.get(descr, rl, rl)
    end

    # @return Html formatted summary for the installation proposal
    def ProposalSummary
      sum = ""
      # summary header
      sum = Summary.OpenList(sum)
      sum = Summary.AddListItem(sum, getRunlevelDescr(@default_runlevel))
      sum = Summary.CloseList(sum)

      sum
    end

    # @return Html formatted configuration summary
    def Summary
      sum = ""
      sum = Summary.AddHeader(sum, _("Default Runlevel"))
      sum = Summary.AddLine(sum, getRunlevelDescr(@default_runlevel))
      # summary header
      sum = Summary.AddHeader(sum, _("Services"))

      if Ops.greater_than(Builtins.size(@services), 0)
        sum = Summary.OpenList(sum)
        Builtins.foreach(@services) do |k, v|
          if Ops.get_boolean(v, "dirty", false)
            item = Builtins.sformat(
              # summary item: %1 service name,
              # %2, %3 list of runlevels it starts/stops in
              _("<p><b>%1</b><br> Start: %2</p>"),
              k,
              Builtins.mergestring(Ops.get_list(v, "start", []), " ")
            )
            sum = Summary.AddListItem(sum, item)
          end
        end
        sum = Summary.CloseList(sum)
      else
        sum = Summary.AddLine(sum, Summary.NotConfigured)
      end
      sum
    end

    # String print
    # @param [String] s a string to add to {#sprint_buffer}
    def sprint(s)
      @sprint_buffer = Ops.add(@sprint_buffer, s)

      nil
    end

    # @return a graphviz graph of the service dependencies
    def DotRequires
      in_attr = {
        "$remote_fs" => "[color=yellow, minlen=2]",
        "$local_fs"  => "[color=green, minlen=2]",
        "$network"   => "[color=magenta, minlen=2]",
        "$syslog"    => "[color=cyan, minlen=2]"
      }
      @sprint_buffer = ""
      sprint("digraph services {\n")
      sprint("\trankdir=LR;\n")
      sprint("\t\"!missing\"[rank=max];\n")
      sprint("\t\"$syslog\" -> \"$network\" [style=invis, minlen=10];\n")
      sprint("\t\"$remote_fs\" -> \"$syslog\" [style=invis, minlen=5];\n")
      Builtins.foreach(@requires) { |n, e| Builtins.foreach(e) do |target|
        attr = Ops.get_string(in_attr, target, "")
        sprint(Builtins.sformat("\t\"%1\" -> \"%2\"%3;\n", n, target, attr))
      end }
      sprint("}\n")
      @sprint_buffer
    end

    #** LiMaL API PART I. - Runlevels in /etc/inittab File **

    def GetCurrentRunlevel
      if @current == nil
        @current = Convert.to_string(
          SCR.Read(path(".init.scripts.current_runlevel"))
        )
      end

      @current == "" ? "unknown" : @current
    end

    def GetDefaultRunlevel
      @default_runlevel
    end

    def SetDefaultRunlevel(rl)
      @default_runlevel = rl
      0
    end

    def GetAvailableRunlevels
      deep_copy(@runlevels)
    end

    #** LiMaL API PART II. - Files and/or Symlinks in /etc/init.d and /etc/rc?.d **
    def ServiceAvailable(service_name)
      Convert.to_boolean(SCR.Read(path(".init.scripts.exists"), service_name))
    end

    def GetAvailableServices(simple)
      s = Builtins.maplist(@services) { |service_name, opts| service_name }
      s = Builtins.filter(s) do |service_name|
        !Builtins.contains(
          Ops.get_list(@services, [service_name, "defstart"], []),
          "B"
        )
      end if simple
      deep_copy(s)
    end

    def GetServiceCurrentStartRunlevels(service_name)
      Ops.get_list(@services, [service_name, "start"], [])
    end

    def GetServiceCurrentStopRunlevels(service_name)
      Ops.get_list(@services, [service_name, "stop"], [])
    end

    #** LiMaL API PART III. - LSB Comments in Init Scripts **

    def GetServiceDefaultStartRunlevels(service_name)
      Ops.get_list(@services, [service_name, "defstart"], [])
    end

    def GetServiceDefaultStopRunlevels(service_name)
      Ops.get_list(@services, [service_name, "defstop"], [])
    end

    #boolean GetServiceDefaultEnabled(string service_name); // not in LSB?

    def GetServiceShortDescription(service_name)
      Ops.get_string(@services, [service_name, "shortdescription"], "")
    end

    def GetServiceDescription(service_name)
      Ops.get_string(@services, [service_name, "description"], "")
    end

    #** LiMaL API PART V. - Installation and Removal of init.d Files **

    # Enable specified service, and all required services.
    # @param [String] service	service name
    # @param [Array<String>] rls		runlevels to enable in or nil for default runlevels
    # @return		0 = ok, 1 = service not found
    def ServiceInstall(service, rls)
      rls = deep_copy(rls)
      return 1 if !Builtins.haskey(@services, service) # service not found

      rls = GetServiceDefaultStartRunlevels(service) if rls == nil

      dep_s = ServiceDependencies(service, true)
      dep_s = FilterAlreadyDoneServices(dep_s, rls, true, true, false)
      Builtins.foreach(dep_s) do |i|
        default_rls = GetServiceDefaultStartRunlevels(i)
        if Builtins.contains(default_rls, "B")
          Ops.set(
            @services,
            [i, "start"],
            Builtins.union(
              ["B"],
              Ops.get_list(@services, [service, "start"], [])
            )
          )
        else
          Ops.set(
            @services,
            [i, "start"],
            Builtins.union(rls, Ops.get_list(@services, [service, "start"], []))
          )
        end
        Ops.set(@services, [i, "dirty"], true)
      end if dep_s != nil
      Ops.set(
        @services,
        [service, "start"],
        Builtins.union(rls, Ops.get_list(@services, [service, "start"], []))
      )
      Ops.set(@services, [service, "dirty"], true)

      0
    end


    # Disable specified service, and all dependence services.
    # @param [String] service	service name
    # @param [Array<String>] rls		runlevels to disable in or nil for default runlevels
    # @return		0 = ok
    def ServiceRemove(service, rls)
      rls = deep_copy(rls)
      return 0 if !Builtins.haskey(@services, service) # service not found (no error)

      rls = GetServiceDefaultStartRunlevels(service) if rls == nil
      dep_s = ServiceDependencies(service, false)
      Builtins.foreach(
        Convert.convert(
          Builtins.union(rls, ["B"]),
          :from => "list",
          :to   => "list <string>"
        )
      ) do |rl|
        dep_s1 = FilterAlreadyDoneServices(dep_s, [rl], false, true, false)
        Builtins.foreach(dep_s) do |j|
          Ops.set(
            @services,
            [j, "start"],
            Builtins.filter(Ops.get_list(@services, [j, "start"], [])) do |i|
              !Builtins.contains(rls, i)
            end
          )
          Ops.set(@services, [j, "dirty"], true)
        end if dep_s1 != nil
      end
      Ops.set(
        @services,
        [service, "start"],
        Builtins.filter(Ops.get_list(@services, [service, "start"], [])) do |i|
          !Builtins.contains(rls, i)
        end
      )
      Ops.set(@services, [service, "dirty"], true)

      0
    end

    # Returns items for default runlevel combo box.
    # (Excludes 0, 1, 6, S and B)
    # @param [Symbol] mode if `auto, adds Unchanged. if `proposal, only 2, 3 and 5
    # @return [Array] List of items. Default is selected.
    def getDefaultPicker(mode)
      items = []
      rls = deep_copy(@runlevels)

      if mode == :auto
        if GetRunlevel4Support() && !Builtins.contains(rls, "4")
          rls = Builtins.sort(Builtins.add(rls, "4"))
        end

        rls = Builtins.prepend(rls, "")
      elsif mode == :proposal
        # We could read the list from SCR (#37071) but
        # inittab in the inst-sys is pre-lsb so we have to override it
        #
        # "4" added because of FATE #303798
        if GetRunlevel4Support()
          rls = ["2", "3", "4", "5"]
        else
          rls = ["2", "3", "5"]
        end
      end
      Builtins.y2milestone("Mode %1 items %2", mode, rls)

      Builtins.foreach(rls) do |i|
        # which ones to avoid: #36110
        if "0" != i && "1" != i && "6" != i && "S" != i && "B" != i
          Ops.set(
            items,
            Builtins.size(items),
            Item(Id(i), getRunlevelDescr(i), i == @default_runlevel)
          )
        end
      end
      deep_copy(items)
    end

    # Init function.
    #
    # @see FATE #303798: YaST2 runlevel editor: offer easy enablement and configuration of runlevel 4
    def Init
      return if @already_initialized

      @already_initialized = true

      supported = ProductFeatures.GetBooleanFeature(
        "globals",
        "rle_offer_rulevel_4"
      )

      if supported == nil
        Builtins.y2milestone(
          "globals/rle_offer_rulevel_4 is missing in control file, runlevel 4 will not be supported"
        )
        supported = false
      end

      SetRunlevel4Support(supported)

      nil
    end

    publish :function => :SetRunlevel4Support, :type => "void (boolean)"
    publish :function => :GetRunlevel4Support, :type => "boolean ()"
    publish :variable => :configuration_already_loaded, :type => "boolean"
    publish :variable => :services_proposal_settings, :type => "list <map <string, any>>"
    publish :variable => :services_proposal_links, :type => "list <string>"
    publish :variable => :x11_selected, :type => "boolean"
    publish :function => :StartContainsImplicitly, :type => "boolean (list <string>, string)"
    publish :variable => :services, :type => "map <string, map>"
    publish :variable => :service_list, :type => "list"
    publish :variable => :default_runlevel, :type => "string"
    publish :variable => :runlevels, :type => "list <string>"
    publish :variable => :current, :type => "string"
    publish :function => :GetCurrentRunlevel, :type => "string ()"
    publish :function => :GetDefaultRunlevel, :type => "string ()"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :ServiceDependencies, :type => "list <string> (string, boolean)"
    publish :function => :FilterAlreadyDoneServices, :type => "list <string> (list <string>, list <string>, boolean, boolean, boolean)"
    publish :function => :ClearServices, :type => "void ()"
    publish :function => :isDisabled, :type => "boolean (string)"
    publish :function => :CheckPortmap, :type => "string ()"
    publish :function => :ServicesDependencies, :type => "list <string> (list <string>)"
    publish :function => :ListOfServicesToStart, :type => "list <string> ()"
    publish :function => :StartServicesWithDependencies, :type => "boolean (list <string>)"
    publish :function => :AdaptServices, :type => "boolean (map <string, map>, boolean)"
    publish :function => :EnableServices, :type => "boolean (list <string>)"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :isDirty, :type => "boolean ()"
    publish :function => :GetModified, :type => "boolean ()"
    publish :function => :SetModified, :type => "void ()"
    publish :function => :Export, :type => "map ()"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :getRunlevelDescr, :type => "string (string)"
    publish :function => :ProposalSummary, :type => "string ()"
    publish :function => :Summary, :type => "string ()"
    publish :function => :DotRequires, :type => "string ()"
    publish :function => :SetDefaultRunlevel, :type => "integer (string)"
    publish :function => :GetAvailableRunlevels, :type => "list <string> ()"
    publish :function => :ServiceAvailable, :type => "boolean (string)"
    publish :function => :GetAvailableServices, :type => "list <string> (boolean)"
    publish :function => :GetServiceCurrentStartRunlevels, :type => "list <string> (string)"
    publish :function => :GetServiceCurrentStopRunlevels, :type => "list <string> (string)"
    publish :function => :GetServiceDefaultStartRunlevels, :type => "list <string> (string)"
    publish :function => :GetServiceDefaultStopRunlevels, :type => "list <string> (string)"
    publish :function => :GetServiceShortDescription, :type => "string (string)"
    publish :function => :GetServiceDescription, :type => "string (string)"
    publish :function => :ServiceInstall, :type => "integer (string, list <string>)"
    publish :function => :ServiceRemove, :type => "integer (string, list <string>)"
    publish :function => :getDefaultPicker, :type => "list (symbol)"
    publish :function => :Init, :type => "void ()"
  end

  RunlevelEd = RunlevelEdClass.new
  RunlevelEd.main
end
