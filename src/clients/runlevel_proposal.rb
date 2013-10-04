# encoding: utf-8

# File:	clients/runlevel_proposal.ycp
# Package:	System Services (Runlevel) (formerly known as Runlevel Editor)
# Summary:	Default runlevel proposal
# Authors:	Michal Svec <msvec@suse.cz>
#
# $Id$
module Yast
  class RunlevelProposalClient < Client
    def main
      Yast.import "Pkg"
      Yast.import "UI"

      textdomain "runlevel"

      Yast.import "Label"
      Yast.import "RunlevelEd"
      Yast.import "Summary"
      Yast.import "Arch"
      Yast.import "ProductFeatures"
      Yast.import "Linuxrc"
      Yast.import "Mode"
      Yast.import "Wizard"
      Yast.import "Popup"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Runlevel proposal started")
      Builtins.y2milestone("Arguments: %1", WFM.Args)

      @func = Convert.to_string(WFM.Args(0))
      @param = Convert.to_map(WFM.Args(1))
      @ret = {}

      RunlevelEd.Init

      # create a textual proposal
      if @func == "MakeProposal"
        @force_reset = Ops.get_boolean(@param, "force_reset", false)

        @warning = ""

        # find out proposal parameters, ie. what it depends on
        # some architectures don't have X at all
        @x11_needed = Arch.x11_setup_needed # constant
        @x11_selected = Pkg.IsSelected("xorg-x11-server") # variable
        @live_medium = Mode.live_installation
        # But if we install over VNC, we want RL 5 (and kdm) even though
        # there's no X.

        @vnc = Linuxrc.vnc # constant
        @ssh = Linuxrc.usessh # constant
        @serial = Linuxrc.serial_console # constant

        # we can be overriden
        @forced_runlevel = Convert.to_string(
          ProductFeatures.GetFeature("globals", "runlevel")
        )

        Builtins.y2milestone(
          "x11_setup_needed: %1, x11_selected: %2, vnc: %3, ssh %4, serial: %5, forced: %6, live_medium: %7",
          @x11_needed,
          @x11_selected,
          @vnc,
          @ssh,
          @serial,
          @forced_runlevel,
          @live_medium
        )

        # check only what the user can change at this time
        # Initially the module variables are nil so the condition triggers
        if RunlevelEd.x11_selected != @x11_selected || @force_reset
          # update parameters
          RunlevelEd.x11_selected = @x11_selected

          # do the proposal
          if !Mode.autoinst
            # the default runlevel selection
            # see also bnc #381426 for live-medium
            RunlevelEd.default_runlevel = @x11_needed && @x11_selected || @live_medium ? "5" : "3"

            # Installation via Serial Console expects using it later
            # bnc #433707
            if @serial
              RunlevelEd.default_runlevel = "3" 
              # Both VNC and SSH installation, let's assume that user wants
              # to continue later using the same runlevel as it uses now
              # bnc #373604
            elsif @vnc == true && @ssh == true
              @display_info = UI.GetDisplayInfo
              # if currently installing in TextMode, 3 is selected, otherwise 5
              RunlevelEd.default_runlevel = Ops.get_boolean(
                @display_info,
                "TextMode",
                false
              ) == true ? "3" : "5" 
              # VNC installation
            elsif @vnc == true
              RunlevelEd.default_runlevel = "5" 
              # ssh installation, no X-configuration possible, bnc #149071
            elsif @ssh == true
              RunlevelEd.default_runlevel = "3"
            end
          end

          if @forced_runlevel != ""
            RunlevelEd.default_runlevel = @forced_runlevel
          end

          Builtins.y2milestone(
            "Default runlevel: %1",
            RunlevelEd.default_runlevel
          )
        end

        # Bugzilla #166918
        if @vnc == true && RunlevelEd.default_runlevel != "5"
          @warning = Ops.add(
            @warning,
            # proposal warning, VNC needs runlevel 5, but the selected one is not 5
            _(
              "<li>VNC needs runlevel 5 to run correctly.\nNo graphical system login will be available after the computer is rebooted.</li>"
            )
          )
        end
        if @ssh == true &&
            !Builtins.contains(["3", "5"], RunlevelEd.default_runlevel)
          @warning = Ops.add(
            @warning,
            # proposal warning, SSH needs runlevel 3 or 5, but the selected one is neither one of them
            _(
              "<li>SSH needs runlevel 3 or 5, but you have currently selected a non-network one.</li>"
            )
          )
        end

        @proposal = RunlevelEd.ProposalSummary

        @ret = { "preformatted_proposal" => @proposal }

        # set warning, if it is not empty
        if @warning != ""
          Ops.set(@ret, "warning_level", :warning)
          Ops.set(@ret, "warning", Ops.add(Ops.add("<ul>", @warning), "</ul>"))
        end

        Builtins.y2milestone("Runlevel proposal: %1", @ret)
      # run the module
      elsif @func == "AskUser"
        @stored = RunlevelEd.Export
        @result = RLDialog()
        RunlevelEd.Import(@stored) if @result != :next
        Builtins.y2debug("stored=%1", @stored)
        Builtins.y2debug("result=%1", @result)
        @ret = { "workflow_sequence" => @result }
      # create titles
      elsif @func == "Description"
        @ret = {
          # Rich text title
          "rich_text_title" => _("Default Runlevel"),
          # MenuButton title
          "menu_title"      => _("&Default Runlevel"),
          "id"              => "runlevel"
        }
      # write the proposal
      elsif @func == "Write"
        Builtins.y2milestone("Not writing yet, will be done in inst_finish")
      else
        Builtins.y2error("unknown function: %1", @func)
      end

      # Finish
      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("Runlevel proposal finished")
      Builtins.y2milestone("----------------------------------------")
      deep_copy(@ret) 

      # EOF
    end

    # Bugzilla #166918
    def CheckSelectedRunlevel(selected_runlevel)
      if selected_runlevel == nil
        Builtins.y2error("CheckSelectedRunlevel(nil)")
        return true
      end

      vnc = Linuxrc.vnc
      ssh = Linuxrc.usessh

      # VNC needs runlevel 5
      if vnc && selected_runlevel != "5"
        Builtins.y2warning(
          "VNC nstallation, but selected mode is %1",
          selected_runlevel
        )
        return Popup.YesNo(
          Builtins.sformat(
            # popup question, %1 means the current runlevel (number)
            _(
              "VNC needs runlevel 5 to run correctly.\n" +
                "No graphical system login will be available\n" +
                "after the computer is rebooted.\n" +
                "\n" +
                "Are you sure you want to use runlevel %1 instead?"
            ),
            selected_runlevel
          )
        ) 
        # SSH (installation) needs network
      elsif ssh && !Builtins.contains(["3", "5"], selected_runlevel)
        Builtins.y2warning(
          "SSHD nstallation, but selected mode is %1",
          selected_runlevel
        )
        return Popup.YesNo(
          Builtins.sformat(
            # popup question, %1 means the current runlevel (number)
            _(
              "SSH needs running network.\n" +
                "You have selected a non-network runlevel.\n" +
                "Recommended runlevels are 3 or 5.\n" +
                "\n" +
                "Are you sure you want to use %1 instead?"
            ),
            selected_runlevel
          )
        )
      end

      true
    end

    def RLDialog
      known_runlevels = VBox()
      currently_selected_runlevel = ""

      runlevels = Convert.convert(
        Builtins.sort(RunlevelEd.getDefaultPicker(:proposal)),
        :from => "list",
        :to   => "list <term>"
      )

      Builtins.foreach(runlevels) do |one_runlevel|
        current_id = Ops.get_string(one_runlevel, [0, 0], "")
        known_runlevels = Builtins.add(
          known_runlevels,
          Left(
            RadioButton(
              Id(current_id),
              Builtins.sformat("&%1", Ops.get_string(one_runlevel, 1, ""))
            )
          )
        )
        if Ops.get_boolean(one_runlevel, 2, false) == true
          currently_selected_runlevel = current_id
        end
      end

      # dialog caption
      title = _("Set Default Runlevel")

      contents = VBox(
        RadioButtonGroup(
          Id(:selected_runlevel),
          Frame(
            # frame label
            _("Available Runlevels"),
            HSquash(MarginBox(0.5, 0.5, known_runlevels))
          )
        )
      )

      # made by rwalter@novell.com, bug #206664 comment #8
      # help for runlevel - installation proposal, part 1
      help = _("<p><b><big>Selecting the Default Runlevel</big</b></p>") +
        # help for runlevel - installation proposal, part 2
        _(
          "<p>The runlevel is the setting that helps determine which services are\n" +
            "available by default. Select the level that includes the services this system\n" +
            "should allow when the system starts.</p>"
        ) +
        # help for runlevel - installation proposal, part 3
        _(
          "<p>Runlevel <b>2</b> allows multiple users to log in to the system locally, but\n" +
            "no network or network services are available.  This setting is rarely used as\n" +
            "the default.</p>"
        ) +
        # help for runlevel - installation proposal, part 4
        _(
          "<p>Runlevel <b>4</b> is an expert user mode. Don't use it unless you really\nneed it.</p>"
        ) +
        # help for runlevel - installation proposal, part 5
        _(
          "<p>Runlevel <b>3</b> allows both local and remote logins and enables the\n" +
            "network and any configured network services.  This setting does not start the\n" +
            "graphical login manager, so graphical user interfaces cannot be used\n" +
            "immediately.</p>"
        ) +
        # help for runlevel - installation proposal, part 6
        _(
          "<p>Runlevel <b>5</b> is the most common default runlevel for workstations.  In\n" +
            "addition to the network, it starts the X display manager, which allows\n" +
            "graphical logins.  It also starts any other configured services.</p>"
        ) +
        # help for runlevel - installation proposal, part 7
        _(
          "<p>If you are not sure what to select, runlevel <b>5</b> is generally a good\n" +
            "choice for workstations.  Runlevel <b>3</b> is often used on servers that do\n" +
            "not have a monitor and should not use graphical interfaces.</p>"
        )

      Wizard.CreateDialog
      Wizard.SetTitleIcon("yast-runlevel")

      Wizard.SetContentsButtons(
        title,
        contents,
        help,
        Label.BackButton,
        Label.OKButton
      )
      Wizard.SetAbortButton(:cancel, Label.CancelButton)
      Wizard.HideBackButton

      if currently_selected_runlevel != "" && currently_selected_runlevel != nil
        UI.ChangeWidget(
          Id(:selected_runlevel),
          :CurrentButton,
          currently_selected_runlevel
        )
      end

      dialog_ret = nil

      while true
        ret = UI.UserInput
        Builtins.y2milestone("UI Ret: %1", ret)

        if ret == :next || ret == :ok
          selected_runlevel = Convert.to_string(
            UI.QueryWidget(Id(:selected_runlevel), :CurrentButton)
          )

          # if the selected runlevel is OK
          # or user explicitly accepts the wrong runlevel...
          if CheckSelectedRunlevel(selected_runlevel)
            dialog_ret = :next
            RunlevelEd.default_runlevel = selected_runlevel
            break 
            # next loop
          else
            next
          end
        else
          dialog_ret = :cancel
          break
        end
      end
      Builtins.y2milestone("Selected Runlevel: %1", RunlevelEd.default_runlevel)

      Wizard.CloseDialog

      dialog_ret
    end
  end
end

Yast::RunlevelProposalClient.new.main
