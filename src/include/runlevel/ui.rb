# encoding: utf-8

# File:
#   ui.ycp
#
# Module:
#   System Services (Runlevel) (formerly known as Runlevel Editor)
#
# Summary:
#   Runlevel Editor user interface.
#
# Authors:
#   Martin Vidner <mvidner@suse.cz>
#   Petr Blahos <pblahos@suse.cz>
#   Martin Lazar <mlazar@suse.cz>
#
# $Id$
#
# Runlevel editor user interface functions.
module Yast
  module RunlevelUiInclude
    def initialize_runlevel_ui(include_target)
      Yast.import "UI"
      textdomain "runlevel"

      Yast.import "Service"
      Yast.import "RunlevelEd"
      Yast.import "Wizard"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "FileUtils"
      Yast.import "String"

      @current_service = ""
      @do_abort_now = false

      # We read service status when dialog with services is shown.
      # We read status for services taken from list of services (service_list)
      # and then update map services.
      @fetching_service_index = 0
      # when fetching_service_status becomes false, we stop fetching services
      @fetching_service_status = true

      # columns in the table where these items are located
      # -1 means it is not there
      @c_dirty = -1
      @c_bstatus = -1
      @c_rstatus = -1
      @c_runlevels = -1
      @c_descr = -1
      # index into table column for each runlevel
      @runlevel2tableindex = {}

      # map of services listed in table
      @service_ids_listed_in_table = {}

      @fetched_service_status = {}
    end

    # Create term of checkboxes for runlevel selection.
    # @return HBox full of checkboxes.
    def getRlCheckBoxes
      rls = HBox(Opt(:hstretch))
      Builtins.foreach(RunlevelEd.runlevels) do |i|
        if Ops.greater_than(Builtins.size(rls), 1)
          rls = Builtins.add(rls, HStretch())
        end
        rls = Builtins.add(rls, CheckBox(Id(i), Opt(:notify), Ops.add("&", i)))
      end
      deep_copy(rls)
    end
    # Changes value of a runlevel checkbox.
    # Prevents triggering userinput by disabling notify.
    # @param [Hash] service {#service}
    # @param [String] rl which runlevel
    def updateRlCheckBox(service, rl)
      service = deep_copy(service)
      start = Ops.get_list(service, "start", [])
      old_notify = Convert.to_boolean(UI.QueryWidget(Id(rl), :Notify))
      UI.ChangeWidget(Id(rl), :Notify, false)
      UI.ChangeWidget(Id(rl), :Value, Builtins.contains(start, rl))
      UI.ChangeWidget(Id(rl), :Notify, old_notify)

      nil
    end
    # Changes values of runlevel checkboxes.
    # @param [Hash] service {#service}
    def updateRlCheckBoxes(service)
      service = deep_copy(service)
      Builtins.foreach(RunlevelEd.runlevels) { |i| updateRlCheckBox(service, i) }

      nil
    end
    # Update the long description text box
    # @param [Hash] service {#service}
    def updateDescription(service)
      service = deep_copy(service)
      # For the box, use the long description.
      # The short one as a fallback. #20853
      descr = Ops.get_string(service, "description", "")
      descr = Ops.get_string(service, "shortdescription", "") if descr == ""
      UI.ChangeWidget(Id(:description), :Value, descr)

      nil
    end

    # Sets runlevel columns in the table.
    # @param [String] service_name which line
    # @param [Hash] service {#service}
    # @param [Array<String>] rls which columns to update, nil == all
    def updateRlColumns(service_name, service, rls)
      service = deep_copy(service)
      rls = deep_copy(rls)
      return if @c_runlevels == -1

      start = Ops.get_list(service, "start", [])
      rls = deep_copy(RunlevelEd.runlevels) if rls == nil
      Builtins.foreach(rls) do |rl|
        UI.ChangeWidget(
          Id(:table),
          term(
            :Item,
            service_name,
            Ops.get_integer(@runlevel2tableindex, rl, -1)
          ),
          Builtins.contains(start, rl) ? rl : " "
        )
      end

      nil
    end

    # Returns whether the service is listed in the table of services
    #
    # @param [String] service_name
    def ServiceListedInTable(service_name)
      Ops.get(@service_ids_listed_in_table, service_name, false)
    end

    # Update run-time status column.
    # @param [String] service_name which line
    # @param [Fixnum] started status or -1 (unknown yet)
    def updateStatusColumn(service_name, started)
      if Ops.greater_or_equal(@c_rstatus, 0)
        # cannot change item which is not listed in the table
        if ServiceListedInTable(service_name)
          UI.ChangeWidget(
            Id(:table),
            term(:Item, service_name, @c_rstatus),
            StartedText(started)
          )
        end
      end
      if Ops.greater_or_equal(@c_bstatus, 0)
        # cannot change item which is not listed in the table
        if ServiceListedInTable(service_name)
          disabled = RunlevelEd.isDisabled(service_name)
          UI.ChangeWidget(
            Id(:table),
            term(:Item, service_name, @c_bstatus),
            BstatusText(disabled, started)
          )
        end
      end

      nil
    end

    # Helper function for fetching service status in run-time.
    # @param [String] service_name which line
    # @param [Hash] service {#service}
    # @param [Fixnum] started status or -1 (unknown yet)
    def updateStatusInTable(service_name, service, started)
      service = deep_copy(service)
      # just translate the arguments. the callback is generic
      # because of the future simple UI, bug #13789
      updateStatusColumn(service_name, started)

      nil
    end

    # Changes values of runlevel checkboxes.
    # Get the status if not known yet.
    def changeService1(service)
      service = deep_copy(service)
      if Ops.less_than(Ops.get_integer(service, "started", -1), 0)
        outfile = Builtins.sformat(
          "'%1/runlevel_out_%2'",
          SCR.Read(path(".target.tmpdir")),
          String.Quote(@current_service)
        )

        started = Service.RunInitScriptWithTimeOut(
          @current_service,
          Ops.add("status", Builtins.sformat(" 2>&1 1>%1", outfile))
        )

        Ops.set(service, "started", started)
        Ops.set(RunlevelEd.services, @current_service, service)
        updateStatusColumn(@current_service, started)
      end
      updateRlCheckBoxes(service)
      updateDescription(service)

      nil
    end

    # Reads data from checkboxes and updates service
    # and RunlevelEd::services maps.
    # @param [String] service_name which service
    # @param [Hash] service {#service}
    # @return {#service}
    def queryRlCheckBoxes(service_name, service)
      service = deep_copy(service)
      start_in = []
      Builtins.foreach(RunlevelEd.runlevels) do |i|
        if Convert.to_boolean(UI.QueryWidget(Id(i), :Value))
          Ops.set(start_in, Builtins.size(start_in), i)
        end
      end
      if Ops.get_list(service, "start", []) != start_in
        service = Builtins.union(
          service,
          { "start" => start_in, "dirty" => true }
        )
        Ops.set(RunlevelEd.services, service_name, service)
      end
      deep_copy(service)
    end

    # mapping numbers to descriptions
    # Get help text for rcscript start|stop command exit value.
    # @param [Fixnum] exit exit value
    # @return [String] help text
    def getActionReturnHelp(exit)
      descr = {
        # Init script non-status-command return codes
        # http://www.linuxbase.org/spec/gLSB/gLSB/iniscrptact.html
        # status code.
        # Changed "Foo bar." to "foo bar", #25082
        0 => _(
          "success"
        ),
        # 1: handled as default below
        # status code.
        2 => _(
          "invalid or excess arguments"
        ),
        # status code.
        3 => _("unimplemented feature"),
        # status code.
        4 => _("user had insufficient privileges"),
        # status code.
        5 => _("program is not installed"),
        # status code.
        6 => _("program is not configured"),
        # status code.
        7 => _("program is not running")
      }
      # status code.
      Ops.get(descr, exit, _("unspecified error"))
    end
    # Get help text for rcscript status return value
    # according to LSB.
    # @param [Fixnum] exit exit value
    # @return [String] help text
    def getStatusReturnHelp(exit)
      descr = {
        # Init script "status" command return codes
        # http://www.linuxbase.org/spec/gLSB/gLSB/iniscrptact.html
        # status code.
        # Changed "Foo bar." to "foo bar", #25082
        0 => _(
          "program is running"
        ),
        # status code.
        1 => _("program is dead and /var/run pid file exists"),
        # status code.
        2 => _("program is dead and /var/lock lock file exists"),
        # status code.
        3 => _("program is stopped"),
        # status code.
        4 => _("program or service status is unknown")
      }
      # status code.
      Ops.get(descr, exit, _("unspecified error"))
    end

    # @param [Array<String>] rll	a list of runlevels or nil, meaning "all"
    # @return		"in [these] runlevels" (translated)
    def getInRunlevels(rll)
      rll = deep_copy(rll)
      if rll == nil
        # translators: substituted into a message like
        # "To enable/disable foo IN ALL RUNLEVELS, this must be done..."
        # (do not include the trailing comma here)
        return _("in all runlevels")
      else
        s = Builtins.mergestring(rll, ", ")
        # translators: substituted into a message like
        # "To enable/disable foo IN RUNLEVELS 3, 5, this must be done..."
        # (do not include the trailing comma here)
        return Ops.greater_than(Builtins.size(rll), 1) ?
          Builtins.sformat(_("in runlevels %1"), s) :
          Builtins.sformat(_("in runlevel %1"), s)
      end
    end
    def StartedText(started)
      0 == started ?
        # is the service started?
        _("Yes") :
        Ops.greater_than(started, 0) ?
          # is the service started?
          _("No") :
          # is the service started?
          # ???: we do not know yet what is the service state
          _("???")
    end
    def BstatusText(disabled, started)
      # TRANSLATORS: Unknown service status, presented in table
      state = _("???")
      if disabled != nil
        # TRANSLATORS: Unknown service status presented in table
        state = Ops.less_than(started, 0) ?
          _("???") :
          !disabled ?
            # TRANSLATORS: Service status presented in table, Enabled: Yes
            _("Yes") :
            # TRANSLATORS: Service status presented in table, Enabled: No
            _("No")
        if Ops.greater_or_equal(started, 0) &&
            Ops.greater_than(started, 0) != disabled
          state = Ops.add(state, "*")
        end
      end
      state
    end


    #start unsorted
    # Ask if really abort. Uses boolean changed_settings. Sets boolean do_abort_now.
    # @return [Boolean] true if user really wants to abort
    def reallyAbort
      if @do_abort_now || !RunlevelEd.isDirty
        @do_abort_now = true
        return true
      end
      @do_abort_now = Popup.ReallyAbort(true)
      @do_abort_now
    end


    # Create table items from services.
    # For simple mode, also filter out critical services: boot ones.
    # For Expert mode:
    # Mixin: started, start, (short)description.
    # @param [Symbol] mix which items to mix in:<pre>
    #`simple:	id=name, name, bstatus,            (short)description
    #`complex:	id=name, name, rstatus, runlevels, (short)description
    #`auto:	id=name, name, dirty,   runlevels, ?(short)description
    #</pre>
    # @return [Array] List of items for table.
    def servicesToTable(mix)
      m_dirty = mix == :auto
      m_bstatus = mix == :simple
      m_rstatus = mix == :complex
      m_runlevels = mix != :simple
      m_descr = true

      # assume it is not there until placed in
      @c_dirty = -1
      @c_bstatus = -1
      @c_rstatus = -1
      @c_runlevels = -1
      @c_descr = -1
      @runlevel2tableindex = {}

      # filter out services that are too important to be messed with
      # in the simple mode
      services = deep_copy(RunlevelEd.services)
      services = Builtins.filter(services) do |s_name, s|
        !Builtins.contains(Ops.get_list(s, "defstart", []), "B")
      end if mix == :simple

      items = []
      first = true
      Builtins.foreach(services) do |k, v|
        if first
          first = false
          # preserve current service when switching modes
          @current_service = k if !Builtins.haskey(services, @current_service)
        end
        # id=name, name
        item = Item(Id(k), k)
        # column where a item is added
        col = 1
        if m_dirty
          # dirty
          Ops.set(@service_ids_listed_in_table, k, true)
          @c_dirty = col
          item = Builtins.add(
            item,
            Ops.get_boolean(v, "dirty", false) ? UI.Glyph(:CheckMark) : " "
          )
          col = Ops.add(col, 1)
        end
        if m_bstatus
          # boot status
          Ops.set(@service_ids_listed_in_table, k, true)
          disabled = RunlevelEd.isDisabled(k)
          started = Ops.get_integer(v, "started", -1)
          @c_bstatus = col
          item = Builtins.add(item, BstatusText(disabled, started))
          col = Ops.add(col, 1)
        end
        if m_rstatus
          # runtime status
          Ops.set(@service_ids_listed_in_table, k, true)
          started = Ops.get_integer(v, "started", -1)
          @c_rstatus = col
          item = Builtins.add(item, StartedText(started))
          col = Ops.add(col, 1)
        end
        if m_runlevels
          # runlevels
          Ops.set(@service_ids_listed_in_table, k, true)
          rl = Ops.get_list(v, "start", [])
          @c_runlevels = col
          Builtins.foreach(RunlevelEd.runlevels) do |i|
            Ops.set(@runlevel2tableindex, i, col)
            item = Builtins.add(item, Builtins.contains(rl, i) ? i : " ")
            col = Ops.add(col, 1)
          end
        end
        if m_descr
          # (short)description
          # For the table, use the short description.
          # The long one as a fallback. #20853
          Ops.set(@service_ids_listed_in_table, k, true)
          descr = Ops.get_string(v, "shortdescription", "")
          descr = Ops.get_string(v, "description", "") if descr == ""
          @c_descr = col
          item = Builtins.add(item, descr)
          col = Ops.add(col, 1)
        end
        # next
        Ops.set(items, Builtins.size(items), item)
      end
      deep_copy(items)
    end

    # For each service, determines its status and calls a supplied function.
    # @param func function to call
    # @see #updateStatusInTable
    def serviceStatusIterator(use_func)
      return if !@fetching_service_status
      if Ops.greater_or_equal(
          @fetching_service_index,
          Builtins.size(RunlevelEd.service_list)
        )
        @fetching_service_status = false
        return
      end
      service_name = Ops.get_string(
        RunlevelEd.service_list,
        @fetching_service_index,
        ""
      )
      @fetching_service_index = Ops.add(@fetching_service_index, 1)

      # every switch between `complex and `simple the fetching_service_index is changed to zero
      # but only services which were not checked before are checked now
      if Ops.get(@fetched_service_status, service_name, false) == false
        if ServiceListedInTable(service_name)
          updateServiceStatus(use_func, service_name)
          Ops.set(@fetched_service_status, service_name, true)
        end
      end

      nil
    end
    def updateServiceStatus(use_func, service_name)
      if Ops.less_than(
          Ops.get_integer(RunlevelEd.services, [service_name, "started"], -1),
          0
        )
        file_out = Builtins.sformat(
          "'%1/runlevel_out_%2'",
          SCR.Read(path(".target.tmpdir")),
          String.Quote(service_name)
        )

        started = Service.RunInitScriptWithTimeOut(
          service_name,
          Ops.add("status", Builtins.sformat(" 2>&1 1>%1", file_out))
        )

        Ops.set(RunlevelEd.services, [service_name, "started"], started)

        if use_func
          updateStatusInTable(
            service_name,
            Ops.get(RunlevelEd.services, service_name, {}),
            started
          )
        end
      end

      nil
    end

    # help text for progress
    # @return help text
    def getHelpProgress
      # help text
      _(
        "<P><BIG><B>System Service (Runlevel) Initialization</B></BIG><BR>\nPlease wait...</P>\n"
      ) +
        # warning
        _(
          "<p><b>Note:</b> The system services (runlevel editor) is an expert tool. Only change settings if\n you know what you are doing.  Otherwise your system might not function properly afterwards.</p>\n"
        )
    end


    # Enable or disable a service in some runlevels.
    # Set the variables and update the ui (rl columns).
    # @param [String] service_name	a service
    # @param [Array<String>] rls	which runlevels, nil == disable in all
    # @param [Boolean] enable	enabling or disabling?
    def SetService(service_name, rls, enable)
      rls = deep_copy(rls)
      service = Ops.get(RunlevelEd.services, service_name, {})
      start_in = nil
      if rls == nil
        start_in = []
      else
        start = tomap_true(Ops.get_list(service, "start", []))
        Builtins.foreach(rls) { |rl| start = Builtins.add(start, rl, enable) }
        start = Builtins.filter(start) { |k, v| v == true }
        start_in = Convert.convert(
          mapkeys(start),
          :from => "list",
          :to   => "list <string>"
        )
      end

      if Ops.get_list(service, "start", []) != start_in
        service = Builtins.union(
          service,
          { "start" => start_in, "dirty" => true }
        )
        Ops.set(RunlevelEd.services, service_name, service)

        updateRlColumns(service_name, service, rls)
        updateStatusColumn(
          service_name,
          Ops.get_integer(service, "started", -1)
        )
      end

      nil
    end

    # Check that all the services exist (in RunlevelEd::services).
    # If not, popup a list of the missing ones and ask whether
    # continue or not. Filter out the missing ones.
    # @param [Array<String>] services a service list
    # @return [continue?, filtered list]
    def CheckMissingServices(services)
      services = deep_copy(services)
      missing = []
      ok = true
      services = Builtins.filter(services) do |s|
        if Builtins.haskey(RunlevelEd.services, s)
          next true
        else
          Ops.set(missing, Builtins.size(missing), s)
          next false
        end
      end
      if Ops.greater_than(Builtins.size(missing), 0)
        # missing services only occur when enabling
        ok = Popup.ContinueCancel(
          Builtins.sformat(
            # continue-cancel popup when enabling a service
            # %1 is a list of unsatisfied dependencies
            _("These required services are missing:\n%1."),
            formatLine(missing, 40)
          )
        )
      end
      [ok, services]
    end






    #  * Generic function to handle enabling, disabling, starting and
    #  * stoping services and their dependencies, in various runlevels.
    #  * Piece of cake ;-) <br>
    #
    #  * Either of init_time or run_time can be specified (for complex
    #  * mode) or both (for simple mode).
    #
    #  * rls: ignored for -init +run
    #
    #  * What it does: gets dependent services (in the correct order),
    #  * filters ones that are already in the desired state, if there
    #  * are dependencies left, pop up a confirmation dialog, check for
    #  * missing dependencies, perform the action (run-time, then init-time)
    #  * for the deps and the
    #  * service (in this order), displaying output after each error and
    #  * at the end.
    #  *
    #
    #  * @param service_name	name of service
    #  * @param rls		in which run levels, nil == all
    #  * @param enable		on/off
    #  * @param init_time		do enable/disable
    #  * @param run_time		do start/stop
    #  * @return success (may have been canceled because of dependencies)
    def ModifyServiceDep(service_name, rls, enable, init_time, run_time)
      rls = deep_copy(rls)
      Builtins.y2debug(
        1,
        "Modify: %1 %2 %3 %4 %5",
        service_name,
        rls,
        enable,
        init_time ? "+init" : "-init",
        run_time ? "+run" : "-run"
      )
      one = rls != nil ? Builtins.size(rls) == 1 : false
      command = enable ? "start" : "stop"

      # get dependent services
      dep_s = RunlevelEd.ServiceDependencies(service_name, enable)
      Builtins.y2debug("DEP: %1", dep_s)

      # ensure we have already determined the service status (#36171)
      Builtins.foreach(dep_s) do |service_name2|
        updateServiceStatus(false, service_name2)
      end

      # filter ones that are ok already
      dep_s = RunlevelEd.FilterAlreadyDoneServices(
        dep_s,
        rls,
        enable,
        init_time,
        run_time
      )
      Builtins.y2debug("DEP filtered: %1", dep_s)

      doit = Builtins.size(dep_s) == 0
      # if there are dependencies left, pop up a confirmation dialog
      if !doit
        key = (run_time ? "+run" : "-run") + "," +
          (init_time ? "+init" : "-init") + "," +
          (enable ? "on" : "off")
        texts = {
          #"-run,-init,..." does not make sense

          # *disable*
          # continue-cancel popup
          # translators: %2 is "in runlevel(s) 3, 5"
          # or "in all runlevels"
          "-run,+init,off" => _(
            "To disable service %1 %2,\n" +
              "these services must be additionally disabled,\n" +
              "because they depend on it:\n" +
              "%3."
          ),
          # *enable*
          # continue-cancel popup
          # translators: %2 is "in runlevel(s) 3, 5"
          # or "in all runlevels"
          "-run,+init,on"  => _(
            "To enable service %1 %2,\n" +
              "these services must be additionally enabled,\n" +
              "because it depends on them:\n" +
              "%3."
          ),
          # *stop*
          # continue-cancel popup
          "+run,-init,off" => _(
            "To stop service %1,\n" +
              "these services must be additionally stopped,\n" +
              "because they depend on it:\n" +
              "%2."
          ),
          # *start*
          # continue-cancel popup
          "+run,-init,on"  => _(
            "To start service %1,\n" +
              "these services must be additionally started,\n" +
              "because it depends on them:\n" +
              "%2."
          ),
          # *stop and disable*
          # continue-cancel popup
          # translators: %2 is "in runlevel(s) 3, 5"
          # or "in all runlevels"
          "+run,+init,off" => _(
            "To stop service %1 and disable it %2,\n" +
              "these services must be additionally stopped\n" +
              "and disabled, because they depend on it:\n" +
              "%3."
          ),
          # *start and enable*
          # continue-cancel popup
          # translators: %2 is "in runlevel(s) 3, 5"
          # or "in all runlevels"
          "+run,+init,on"  => _(
            "To start service %1 and enable it %2,\n" +
              "these services must be additionally started\n" +
              "and enabled, because it depends on them:\n" +
              "%3."
          )
        }
        dep_formatted = formatLine(dep_s, 40)
        doit = Popup.ContinueCancel(
          Builtins.sformat(
            Ops.get_string(texts, key, "?"),
            service_name,
            # non-init-time does not need the runlevels
            # so we omit it not to confuser the translators
            init_time ?
              getInRunlevels(rls) :
              dep_formatted,
            dep_formatted
          )
        )
      end

      # check for missing services
      if doit
        r = CheckMissingServices(dep_s)
        doit = Ops.get_boolean(r, 0, false)
        dep_s = Ops.get_list(r, 1, [])
      end


      rich_message = ""
      if doit
        # iterate dep_s, not including service_name
        # because we will ask "continue?" on error
        # Foreach with a break: find the failing one
        Builtins.find(dep_s) do |s|
          if run_time
            ret = startStopService(s, command)

            rich_message = Ops.add(rich_message, Ops.get_string(ret, 1, ""))
            exit = Ops.get_integer(ret, 0, -1)
            if exit != 0
              doit = LongContinueCancelHeadlinePopup(
                # popup heading
                _("An error has occurred."),
                RichText(rich_message),
                70,
                10
              )
              # don't show what we've already seen
              rich_message = ""
              if !doit
                next true # break(foreach)
              end
            end
          end
          if init_time
            # set the variables and update the ui
            SetService(s, rls, enable)
          end
          false
        end
      end
      if doit
        # only for service_name
        if run_time
          ret = startStopService(service_name, command)

          rich_message = Ops.add(rich_message, Ops.get_string(ret, 1, ""))
          Popup.LongText("", RichText(rich_message), 70, 5)

          # don't enable the service if it can't be started, #36176
          return false if Ops.get_integer(ret, 0, -1) != 0
        end

        if init_time
          # set the variables and update the ui
          SetService(service_name, rls, enable)
        end
      end
      doit
    end



    # Turns a service on or off in the simple mode, ie. resolving
    # dependencies and for each service doing start,enable or
    # stop,disable.
    # @param [String] service_name	name of service
    # @param rls		in which run levels, nil == all
    # @return success (may have been canceled because of dependencies)
    def SimpleSetServiceDep(service_name, enable)
      rls = enable ?
        Ops.get_list(RunlevelEd.services, [@current_service, "defstart"], []) :
        nil
      ModifyServiceDep(service_name, rls, enable, true, true)
    end




    # Used for enabling/disabling a service and services depending on
    # it in a runlevel or a set of runlevels.
    # @param [String] service_name	name of service
    # @param [Array<String>] rls		in which run levels, nil == all
    # @param [Boolean] enable		enable/disable
    # @return success (may have been canceled because of dependencies)
    def EnableDisableServiceDep(service_name, rls, enable)
      rls = deep_copy(rls)
      ModifyServiceDep(service_name, rls, enable, true, false)
    end


    # Used for starting/stopping a service and services depending on it.
    # Displays result popups.
    # @param [String] service_name	name of service
    # @param [Boolean] enable		start/stop
    # @return success (may have been canceled because of dependencies)
    def StartStopServiceDep(service_name, enable)
      ModifyServiceDep(service_name, [], enable, false, true)
    end

    # BNC #446546: Better busy message
    def ServiceBusyMessage(service_name, command)
      ret = nil

      case command
        when "start"
          # busy message
          ret = Builtins.sformat(_("Starting service %1 ..."), service_name)
        when "stop"
          # busy message
          ret = Builtins.sformat(_("Stopping service %1 ..."), service_name)
        when "status"
          # busy message
          ret = Builtins.sformat(
            _("Checking status of service %1 ..."),
            service_name
          )
        else
          # busy message
          ret = Builtins.sformat(
            _("Running command %1 %2 ..."),
            service_name,
            command
          )
      end

      ret
    end
    def startStopService(service_name, command)
      UI.OpenDialog(Label(ServiceBusyMessage(service_name, command)))
      Builtins.y2milestone("%1 -> %2", service_name, command)

      log_filename = Builtins.sformat(
        "'%1/runlevel_out_%2'",
        Convert.to_string(SCR.Read(path(".target.tmpdir"))),
        String.Quote(service_name)
      )

      cmd_run = Service.RunInitScriptWithTimeOut(
        service_name,
        Ops.add(command, Builtins.sformat(" 2>&1 1>%1", log_filename))
      )
      out = { "exit" => cmd_run }
      if FileUtils.Exists(log_filename)
        Ops.set(
          out,
          "stdout",
          Convert.to_string(SCR.Read(path(".target.string"), log_filename))
        )
      end

      UI.CloseDialog

      exit = Ops.get_integer(out, "exit", -1)
      rich_message = Builtins.sformat(
        # %1 service, %2 command,
        # %3 exit status, %4 status description, %5 stdout
        # added a colon
        _("<p><b>/bin/systemctl %1 %2.service</b> returned %3 (%4):<br>%5</p>"),
        command,
        service_name,
        exit,
        command == "status" ?
          getStatusReturnHelp(exit) :
          getActionReturnHelp(exit),
        Builtins.sformat("<pre>%1</pre>", Ops.get_string(out, "stdout", ""))
      )
      # succesful stop => status: program not running
      started = exit == 0 && command == "stop" ? 3 : exit
      # normally "started" has the exit code of "status",
      # and we may be adding output of a different command
      # but it is only tested against zero anyway
      service = Ops.get(RunlevelEd.services, service_name, {})
      Ops.set(service, "started", started)
      Ops.set(RunlevelEd.services, service_name, service)
      # this won't work in simple mode
      # make a map "item"->column_number, depending on mode
      # then the functions can consult it and do nothing if not present
      updateStatusColumn(service_name, Ops.get_integer(service, "started", -1))
      [exit, rich_message]
    end
    def formatLine(l, len)
      l = deep_copy(l)
      s = ""
      line = "     "
      add_sep = ""
      line_sep = ""
      Builtins.foreach(l) do |i|
        if Ops.greater_than(Builtins.size(line), len)
          s = Ops.add(Ops.add(s, line_sep), line)
          line_sep = ",\n"
          line = "     "
        else
          line = Ops.add(line, add_sep)
        end
        line = Ops.add(line, i)
        add_sep = ", "
      end
      if Ops.greater_than(Builtins.size(line), 0)
        s = Ops.add(Ops.add(s, line_sep), line)
      end
      s
    end

    # Checks what services should run in this runlevel and do not run
    # or what services run but should not run.
    # @return [String] overview text
    def overviewText
      should_not_run = []
      should_run = []
      Builtins.foreach(RunlevelEd.services) do |k, v|
        if RunlevelEd.StartContainsImplicitly(
            Ops.get_list(v, "start", []),
            RunlevelEd.current
          )
          if 0 != Ops.get_integer(v, "started", -1)
            Ops.set(should_run, Builtins.size(should_run), k)
          end
        else
          if 0 == Ops.get_integer(v, "started", -1)
            Ops.set(should_not_run, Builtins.size(should_not_run), k)
          end
        end
      end
      s = ""
      if Ops.greater_than(
          Ops.add(Builtins.size(should_run), Builtins.size(should_not_run)),
          0
        )
        # message label
        s = Ops.add(s, "\n\n") # + _("Overview") + "\n\n"
        if Ops.greater_than(Builtins.size(should_not_run), 0)
          # list of services will follow
          s = Ops.add(
            s,
            _(
              "Following services run in current\nrunlevel although they should not:"
            )
          )
          s = Ops.add(
            Ops.add(Ops.add(s, "\n"), formatLine(should_not_run, 35)),
            "\n\n"
          )
        end

        if Ops.greater_than(Builtins.size(should_run), 0)
          # list of services will follow
          s = Ops.add(
            s,
            _(
              "Following services do not run in current\nrunlevel although they should:"
            )
          )
          s = Ops.add(
            Ops.add(Ops.add(s, "\n"), formatLine(should_run, 35)),
            "\n\n"
          )
        end
      end
      s
    end

    # Radio buttons (faking tabs) for switching modes
    # @param [Symbol] mode `simple or `complex, which one are we in
    # @return RadioButtonGroup term
    def ModeTabs(mode)
      rbg =
        # fake tabs using radio buttons
        RadioButtonGroup(
          Id(:rbg),
          HBox(
            RadioButton(
              Id(:simple),
              Opt(:notify),
              # radio button label
              _("&Simple Mode"),
              mode == :simple
            ),
            HSpacing(3),
            RadioButton(
              Id(:complex),
              Opt(:notify, :key_F7),
              # radio button label
              _("&Expert Mode"),
              mode == :complex
            )
          )
        )
      Left(rbg)
    end


    # help text services dialog
    # @return help text
    def getHelpComplex
      # help text
      # help text
      _(
        "<p>Assign system services to runlevels by selecting the list entry of the respective service then\nchecking or unchecking the <b>check boxes B-S</b> for the runlevel.</p>\n"
      ) +
        # help text
        _(
          "<p><b>Start/Stop/Refresh:</b> Use this to start or stop services individually.</p>"
        ) +
        # help text
        _(
          "<P><B>Set and Reset:</B>\n" +
            "Select runlevels in which to run the currently selected service.<ul>\n" +
            "<li><b>Enable the service:</b> Activates the service in the standard runlevels.</li>\n" +
            "<li><b>Disable the service:</b> Deactivates service.</li>\n" +
            "<li><b>Enable all services:</b> Activates all services in their standard runlevels.</li>\n" +
            "</ul></p>\n"
        ) +
        # The change does not occur immediately. After a reboot the system boots into the specified runlevel.
        _(
          "<p>Changes to the <b>default runlevel</b> will take effect next time you boot your computer.</p>"
        )
    end

    # Main dialog for changing services.
    # @return [Symbol] for wizard sequencer
    def ComplexDialog
      Wizard.SetScreenShotName("runlevel-2-services")

      # currently selected service we are working with
      service = {}

      header = Header(
        # table header
        _("Service"),
        # table header. is a service running?
        _("Running")
      )
      Builtins.foreach(RunlevelEd.runlevels) do |i|
        #	    header = add (header, `Center (" " + i + " "));
        header = Builtins.add(header, Center(i))
      end
      # headers in table
      header = Builtins.add(header, _("Description"))

      args = WFM.Args
      # should we show debugging buttons?
      show_debug = Ops.get_string(args, 0, "") == "debug"
      # should we show the Restore to default button?
      show_restore = true

      contents = VBox(
        VSpacing(0.4),
        ModeTabs(:complex),
        # `HBox (
        # 		// preserve 2 spaces at the end.
        # 		`Label (_("Current runlevel:  ")),
        # 		`Label (`opt (`outputField, `hstretch), getRunlevelDescr (RunlevelEd::current))
        # 		),
        # combo box label
        ComboBox(
          Id(:default_rl),
          Opt(:hstretch),
          _("&Set default runlevel after booting to:"),
          RunlevelEd.getDefaultPicker(:complex)
        ),
        VSpacing(0.4),
        Table(
          Id(:table),
          Opt(:notify, :immediate),
          header,
          servicesToTable(:complex)
        ),
        VSquash(
          HBox(
            VSpacing(4.3), # 3+borders in qt, 3 in curses
            RichText(Id(:description), Opt(:shrinkable, :vstretch), "")
          )
        ),
        VBox(
          # label above checkboxes
          Label(
            Id(:service_label),
            Opt(:hstretch),
            _("Service will be started in following runlevels:")
          ),
          getRlCheckBoxes
        ),
        HBox(
          # menubutton label
          MenuButton(
            _("S&tart/Stop/Refresh"),
            [
              # menu item
              Item(Id(:start), _("&Start now ...")),
              # menu item
              Item(Id(:stop), _("S&top now ...")),
              # menu item
              Item(Id(:restart), _("R&estart now ...")),
              # menu item
              Item(Id(:status), _("&Refresh status ..."))
            ]
          ),
          HStretch(),
          ReplacePoint(
            Id(:menubutton),
            # menubutton label
            MenuButton(
              _("Set/&Reset"),
              Ops.add(
                Ops.add(
                  Ops.add(
                    [
                      # menu item
                      Item(
                        Id(:to_enable), #`opt (`key_F3),
                        _("&Enable the service")
                      ),
                      # menu item
                      Item(
                        Id(:to_disable), #`opt (`key_F5),
                        _("&Disable the service")
                      )
                    ],
                    !show_restore ?
                      [] :
                      #TODO
                      []
                  ),
                  [
                    # menu item
                    Item(Id(:to_all_enable), _("Enable &all services"))
                  ]
                ),
                !show_debug ?
                  [] :
                  [
                    # menu item
                    Item(Id(:depviz), _("Save Dependency &Graph"))
                  ]
              )
            )
          )
        )
      )
      # dialog caption.
      Wizard.SetContents(
        _("System Services (Runlevel): Details"),
        contents,
        getHelpComplex,
        true,
        true
      )
      Wizard.HideBackButton

      UI.ChangeWidget(Id(:table), :CurrentItem, @current_service)
      service = Ops.get(RunlevelEd.services, @current_service, {})
      changeService1(service)

      ret = nil

      # fetch service which were not checked before
      @fetching_service_status = true
      @fetching_service_index = 0

      while :next != ret && :back != ret && :abort != ret && :simple != ret
        Builtins.y2milestone("RET: %1", ret) if ret != nil && ret != :table

        # Kludge, because a `Table still does not have a shortcut.
        # #16116
        UI.SetFocus(Id(:table))

        if @fetching_service_status
          ret = UI.PollInput
          UI.NormalCursor
          if nil == ret
            serviceStatusIterator(true)
            next
          end
          UI.BusyCursor
        else
          ret = UI.UserInput
        end
        ret = :abort if ret == :cancel

        @current_service = Convert.to_string(
          UI.QueryWidget(Id(:table), :CurrentItem)
        )
        Builtins.y2milestone("Current service: %1", @current_service)

        if :abort == ret
          if !reallyAbort
            ret = nil
            next
          end
        elsif :next == ret
          # TODO: check dependencies of all services? (on demand?)
          # string nfs_adj = RunlevelEd::CheckPortmap ();
          # ...

          if RunlevelEd.isDirty
            # yes-no popup
            if !Popup.YesNo(_("Now the changes to runlevels \nwill be saved."))
              ret = nil
              next
            end
          end
          RunlevelEd.default_runlevel = Convert.to_string(
            UI.QueryWidget(Id(:default_rl), :Value)
          )
          break
        elsif :table == ret
          service = Ops.get(RunlevelEd.services, @current_service, {})
          changeService1(service)
        elsif nil != ret && Ops.is_string?(ret)
          # checkbox pressed
          # - enable/disable current_service in one runlevel
          enable = Convert.to_boolean(UI.QueryWidget(Id(ret), :Value))
          rls = Convert.convert([ret], :from => "list", :to => "list <string>")
          if !EnableDisableServiceDep(
              @current_service,
              Convert.convert([ret], :from => "list", :to => "list <string>"),
              enable
            )
            # restore the check box
            updateRlCheckBox(service, Convert.to_string(ret))
          end
        elsif :depviz == ret
          filename = UI.AskForSaveFileName(".", "*", "")
          SCR.Write(path(".target.string"), filename, RunlevelEd.DotRequires)
        elsif :to_enable == ret
          default_runlevel = Ops.get_list(
            RunlevelEd.services,
            [@current_service, "defstart"],
            []
          )
          EnableDisableServiceDep(@current_service, default_runlevel, true)
          service = Ops.get(RunlevelEd.services, @current_service, {})
          changeService1(service)
        elsif :to_disable == ret
          EnableDisableServiceDep(@current_service, nil, false)
          service = Ops.get(RunlevelEd.services, @current_service, {})
          changeService1(service)
        elsif :to_all_enable == ret
          # yes-no popup
          if Popup.YesNo(_("Really enable all services?"))
            Builtins.foreach(RunlevelEd.services) do |k, v|
              setServiceToDefault(k)
            end
            UI.ChangeWidget(Id(:table), :Items, servicesToTable(:complex))
            # message popup
            Popup.Message(
              _("Each service was enabled\nin the appropriate runlevels.")
            )
          end
        elsif :start == ret || :stop == ret || :restart == ret
          # restarting a service which is not started equals to its starting
          # and dependency check is needed
          if :restart == ret && 0 != Service.Status(@current_service)
            ret = :start
          end
          really = true
          if :stop == ret &&
              Builtins.contains(["xdm", "earlyxdm"], @current_service)
            # yes-no popup. the user wants to stop xdm
            if !Popup.YesNo(_("This may kill your X session.\n\nProceed?"))
              really = false
            end
          end
          if really
            if ret == :restart
              ret2 = startStopService(@current_service, "restart")
              Popup.LongText("", RichText(Ops.get_string(ret2, 1, "")), 70, 5)
            else
              StartStopServiceDep(@current_service, ret == :start)
            end
          end
        elsif :status == ret
          # similar to startStopService but there will be changes
          # when dependencies are checked

          #TODO: find a place for it
          #Popup::Message (overviewText ());
          r = startStopService(@current_service, "status")
          Popup.LongText("", RichText(Ops.get_string(r, 1, "")), 70, 5)
        end
      end

      Wizard.RestoreScreenShotName
      Convert.to_symbol(ret)
    end

    # simple mode
    # Main dialog for changing services.
    # @return [Symbol] for wizard sequencer
    def SimpleDialog
      Wizard.SetScreenShotName("runlevel-2-simple")
      service = {}

      help_text =
        # Simple mode dialog
        # help text
        _("<p>Here, specify which system services should be started.</p>") +
          # warning
          _(
            "<p><b>Warning:</b> The system services (runlevel editor) is an expert tool. Only change settings if you know\n what you are doing.  Otherwise your system might not function properly afterwards.</p>\n"
          ) +
          # help text
          # 'Enable' is a button, 'Disable' is a button
          _(
            "<p><b>Enable</b> starts the selected service and services\n" +
              "that it depends on and enables them to start at system boot time.\n" +
              "Likewise, <b>Disable</b> stops a service and all depending services\n" +
              "and disables their start at system boot time.</p>\n"
          ) +
          # help text
          _(
            "<p>An asterisk (*) after a service status means that the service is enabled but not running or is disabled but running now.</p>"
          ) +
          # help text
          _(
            "<p>To change the behavior of runlevels and system services in detail, click <b>Expert Mode</b>.</p>\n"
          )

      contents = VBox(
        VSpacing(0.4),
        ModeTabs(:simple),
        VSpacing(0.4),
        Table(
          Id(:table),
          Opt(:notify, :immediate),
          Header(_("Service"), _("Enabled"), _("Description")),
          servicesToTable(:simple)
        ),
        VSquash(
          HBox(
            VSpacing(4.3), # 3+borders in qt, 3 in curses
            RichText(Id(:description), Opt(:shrinkable, :vstretch), "")
          )
        ),
        Left(
          HBox(
            # Button label
            PushButton(Id(:enable), Opt(:key_F3), _("&Enable")),
            # Button label
            PushButton(Id(:disable), Opt(:key_F5), _("&Disable"))
          )
        )
      )
      # dialog caption.
      Wizard.SetContentsButtons(
        _("System Services (Runlevel): Services"),
        contents,
        help_text,
        Label.BackButton,
        Label.OKButton
      )
      Wizard.SetAbortButton(:abort, Label.CancelButton)
      Wizard.HideBackButton

      UI.ChangeWidget(Id(:table), :CurrentItem, @current_service)
      service = Ops.get(RunlevelEd.services, @current_service, {})
      updateDescription(service)


      UI.SetFocus(Id(:table))
      ret = nil
      focustable = false

      # fetch service which were not checked before
      @fetching_service_status = true
      @fetching_service_index = 0

      while :next != ret && :back != ret && :abort != ret && :complex != ret
        Builtins.y2milestone("RET: %1", ret) if ret != nil
        if focustable
          # Kludge, because a `Table still does not have a shortcut.
          # #16116
          UI.SetFocus(Id(:table))
        end

        if @fetching_service_status
          ret = UI.PollInput
          UI.BusyCursor
          if nil == ret
            serviceStatusIterator(true)
            next
          end
        else
          ret = UI.UserInput
          focustable = true
        end
        ret = :abort if ret == :cancel

        @current_service = Convert.to_string(
          UI.QueryWidget(Id(:table), :CurrentItem)
        )

        if :abort == ret
          if !reallyAbort
            ret = nil
            next
          end
        elsif :next == ret
          # FIXME copied from ComplexDialog, make it a function
          # Misaligned for consistency with the original

          # TODO: check dependencies of all services? (on demand?)
          # string nfs_adj = RunlevelEd::CheckPortmap ();
          # ...

          if RunlevelEd.isDirty
            # yes-no popup
            if !Popup.YesNo(_("Now the changes to runlevels \nwill be saved."))
              ret = nil
              next
            end
          end
          break
        elsif ret == :table
          service = Ops.get(RunlevelEd.services, @current_service, {})
          updateDescription(service)
        elsif ret == :disable
          Builtins.y2milestone(
            "Current service: %1 / %2",
            @current_service,
            ret
          )
          really = true

          if Builtins.contains(["xdm", "earlyxdm"], @current_service)
            # yes-no popup. the user wants to stop xdm
            if !Popup.YesNo(_("This may kill your X session.\n\nProceed?"))
              Builtins.y2warning(
                "User decided to stop '%1' despite the warning",
                @current_service
              )
              really = false
            end
          end

          SimpleSetServiceDep(@current_service, false) if really
        elsif :enable == ret
          Builtins.y2milestone(
            "Current service: %1 / %2",
            @current_service,
            ret
          )
          SimpleSetServiceDep(@current_service, true)
        end
      end
      Wizard.RestoreScreenShotName
      Convert.to_symbol(ret)
    end


    # Autoyast UI
    # Help text for auto-complex-screen
    # @return help text
    def getHelpAuto
      # help text
      _("<p><b>Prepare data for autoinstallation.</b></p>") +
        # help text
        _(
          "<p>Change the services to requested state. Only services marked as changed will really be changed in the target system.</p>"
        ) +
        # help text
        _(
          "<p>If you made a mistake and want to undo the change, press <b>Clear</b> or <b>Clear all</b>.</p>"
        )
    end
    # Add service by hand.
    # @return new service name (already added to RunlevelEd::services) or ""
    def addService
      UI.OpenDialog(
        VBox(
          # dialog heading
          Heading(Opt(:hstretch), _("Add service")),
          VSpacing(1),
          # text entry
          TextEntry(Id(:name), _("Service &name")),
          # label
          Label(Opt(:hstretch), _("Starts in these runlevels by default:")),
          getRlCheckBoxes,
          VSpacing(1),
          # text entry
          TextEntry(Id(:des), _("&Description (optional)"), ""),
          VSpacing(1),
          ButtonBox(
            PushButton(Id(:ok), Opt(:default), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )
      UI.SetFocus(Id(:name))

      ret = nil # (symbol|string)
      name = ""
      while true
        ret = UI.UserInput
        if :ok == ret
          name = Convert.to_string(UI.QueryWidget(Id(:name), :Value))
          if nil == name || "" == name ||
              Builtins.haskey(RunlevelEd.services, name)
            # message popup
            Popup.Message(
              _(
                "Invalid service name. You did not specify service\nname or the name specified is already in use."
              )
            )
            next
          end
          _def = []
          Builtins.foreach(RunlevelEd.runlevels) do |i|
            if Convert.to_boolean(UI.QueryWidget(Id(i), :Value))
              Ops.set(_def, Builtins.size(_def), i)
            end
          end
          m = {
            "dirty"       => true,
            "defstart"    => _def,
            "start"       => _def,
            "description" => UI.QueryWidget(Id(:des), :Value)
          }
          Ops.set(RunlevelEd.services, name, m)
          break
        end
        if :cancel == ret
          name = ""
          break
        end
      end
      UI.CloseDialog
      name
    end

    # Main dialog for changing services.
    # @return [Symbol] for wizard sequencer
    def AutoDialog
      Wizard.SetScreenShotName("runlevel-2-auto")
      # currently selected service we are working with
      service = {}

      # Sets columns 0-S (runlevels) in table so they are synchronized with checkboxes.
      refreshTableLine2 = lambda do
        updateRlColumns(@current_service, service, nil)
        UI.ChangeWidget(
          Id(:table),
          term(:Item, @current_service, @c_dirty),
          Ops.get_boolean(service, "dirty", false) ? UI.Glyph(:CheckMark) : " "
        )

        nil
      end

      # headers in table
      header = Header(
        # table header
        _("Service"),
        # table header. has the service state changed?
        _("Changed")
      )
      Builtins.foreach(RunlevelEd.runlevels) do |i|
        #	    header = add (header, `Center (" " + i + " "));
        header = Builtins.add(header, Center(i))
      end
      # headers in table
      header = Builtins.add(header, _("Description"))
      contents = VBox(
        VSpacing(0.4),
        # combo box label
        ComboBox(
          Id(:default_rl),
          Opt(:hstretch),
          _("&Set default runlevel after booting to:"),
          RunlevelEd.getDefaultPicker(:auto)
        ),
        VSpacing(0.4),
        Table(
          Id(:table),
          Opt(:notify, :immediate),
          header,
          servicesToTable(:auto)
        ),
        VBox(
          # label above checkboxed
          Label(
            Id(:service_label),
            Opt(:hstretch),
            _("Service will be started in following runlevels:")
          ),
          getRlCheckBoxes
        ),
        HBox(
          # button label
          PushButton(Id(:add), Opt(:key_F3), _("A&dd")),
          HStretch(),
          # button label
          PushButton(Id(:clear), _("&Clear")),
          # button label
          PushButton(Id(:clear_all), _("Clea&r All")),
          # button label
          PushButton(Id(:default), _("D&efault"))
        )
      )
      # dialog caption.
      Wizard.SetContentsButtons(
        _("System Services (Runlevel): Details"),
        contents,
        getHelpAuto,
        Label.BackButton,
        Label.OKButton
      )
      Wizard.SetAbortButton(:abort, Label.CancelButton)
      Wizard.HideBackButton

      UI.ChangeWidget(Id(:table), :CurrentItem, @current_service)
      service = Ops.get(RunlevelEd.services, @current_service, {})
      updateRlCheckBoxes(service)
      ret = nil
      while nil != UI.PollInput
        Builtins.sleep(50)
      end
      while :next != ret && :back != ret && :abort != ret
        # Kludge, because a `Table still does not have a shortcut.
        # #16116
        UI.SetFocus(Id(:table))

        ret = UI.UserInput
        ret = :abort if ret == :cancel

        if :abort == ret
          if !reallyAbort
            ret = nil
            next
          end
        elsif :next == ret
          #FIXME dependencies none or proper

          nfs_adj = RunlevelEd.CheckPortmap
          if nil != nfs_adj
            UI.ChangeWidget(Id(:table), :CurrentItem, "portmap")
            @current_service = "portmap"
            service = Ops.get(RunlevelEd.services, "portmap", {})
            updateRlCheckBoxes(service)
            while nil != UI.PollInput
              Builtins.sleep(50)
            end
            # yes-no popup
            if !Popup.YesNo(
                Builtins.sformat(
                  _(
                    "Service portmap, which is required by\n" +
                      "%1, is disabled. Enable\n" +
                      "portmap if you want to run %1.\n" +
                      "\n" +
                      "Leave portmap\n" +
                      "disabled?\n"
                  ),
                  nfs_adj
                )
              )
              ret = nil
              next
            end
          end
          RunlevelEd.default_runlevel = Convert.to_string(
            UI.QueryWidget(Id(:default_rl), :Value)
          )
          break
        elsif :add == ret
          name = addService
          if "" != name
            UI.ChangeWidget(Id(:table), :Items, servicesToTable(:auto))
            UI.ChangeWidget(Id(:table), :CurrentItem, name)
            # qt and curses behave differently:
            # one of them sends notification after changewidget
            # and the other does not.
            # So eat it.
            while nil != UI.PollInput
              Builtins.sleep(50)
            end
            ret = :table
          end
        elsif :default == ret
          setServiceToDefault(@current_service)
          service = Ops.get(RunlevelEd.services, @current_service, {})
          refreshTableLine2.call
          ret = :table
        elsif :clear == ret
          # re-read from SCR
          service = Service.Info(@current_service)
          Ops.set(RunlevelEd.services, @current_service, service)
          refreshTableLine2.call
          ret = :table
        elsif :clear_all == ret
          RunlevelEd.ClearServices
          UI.ChangeWidget(Id(:table), :Items, servicesToTable(:auto))
          ret = :table
        elsif nil != ret && Ops.is_string?(ret)
          # checkbox pressed
          # checked or unchecked?
          checked = Convert.to_boolean(UI.QueryWidget(Id(ret), :Value)) ?
            Convert.to_string(ret) :
            " "
          service = queryRlCheckBoxes(@current_service, service)
          UI.ChangeWidget(
            Id(:table),
            term(
              :Item,
              @current_service,
              Ops.get_integer(@runlevel2tableindex, ret, -1)
            ),
            checked
          )
          UI.ChangeWidget(
            Id(:table),
            term(:Item, @current_service, @c_dirty),
            UI.Glyph(:CheckMark)
          )
        end

        # not a part of the else-if chain above!
        if :table == ret
          @current_service = Convert.to_string(
            UI.QueryWidget(Id(:table), :CurrentItem)
          )
          service = Ops.get(RunlevelEd.services, @current_service, {})
          updateRlCheckBoxes(service)
          while nil != UI.PollInput
            Builtins.sleep(50)
          end
        end
      end
      Wizard.RestoreScreenShotName
      Convert.to_symbol(ret)
    end
    def LongContinueCancelHeadlinePopup(headline, richtext, hdim, vdim)
      richtext = deep_copy(richtext)
      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          VSpacing(vdim),
          VBox(
            HSpacing(hdim),
            Left(Heading(headline)),
            VSpacing(0.2),
            richtext, # scrolled text
            ButtonBox(
              PushButton(Id(:continue), Opt(:default), Label.ContinueButton),
              PushButton(Id(:cancel), Label.CancelButton)
            )
          )
        )
      )

      UI.SetFocus(Id(:continue))

      ret = UI.UserInput == :continue
      UI.CloseDialog
      ret
    end

    # move them to the module
    # (no ui interaction)
    # Disable the service. Changes global services.
    # @param [String] service_name name of the service.
    def setServiceDisable(service_name)
      service = Ops.get(RunlevelEd.services, service_name, {})
      Ops.set(
        RunlevelEd.services,
        service_name,
        Builtins.union(service, { "start" => [], "dirty" => true })
      )

      nil
    end
    def setServiceToDefault(service_name)
      service = Ops.get(RunlevelEd.services, service_name, {})
      Ops.set(
        RunlevelEd.services,
        service_name,
        Builtins.union(
          service,
          { "start" => Ops.get_list(service, "defstart", []), "dirty" => true }
        )
      )

      nil
    end
    def tomap_true(l)
      l = deep_copy(l)
      Builtins.listmap(l) { |i| { i => true } }
    end
    def mapkeys(m)
      m = deep_copy(m)
      Builtins.maplist(m) { |k, v| k }
    end
  end
end
