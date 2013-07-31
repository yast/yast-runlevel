# encoding: utf-8

# File:	wizard.ycp
# Module:	System Services (Runlevel) (formerly known as Runlevel Editor)
# Summary:	Wizards definitions
# Authors:	Petr Blahos <pblahos@suse.cz>, 2001
#		Martin Lazar <mlazar@suse.cz>, 2004
#
# $Id$
#
module Yast
  module RunlevelWizardInclude
    def initialize_runlevel_wizard(include_target)
      Yast.import "UI"
      textdomain "runlevel"

      Yast.import "RunlevelEd"
      Yast.import "Wizard"
      Yast.import "Sequencer"
      Yast.import "Confirm"

      Yast.include include_target, "runlevel/ui.rb"
    end

    def ReadDialog
      #    Wizard::RestoreHelp(HELPS["read"]:"");

      # checking for root permissions
      return :abort if !Confirm.MustBeRoot

      ret = RunlevelEd.Read
      ret ? :next : :abort
    end

    # Write settings dialog
    # @return `abort if aborted and `next otherwise
    def WriteDialog
      #    Wizard::RestoreHelp(HELPS["write"]:"");
      ret = RunlevelEd.Write
      ret ? :next : :abort
    end


    def MainSequence
      aliases = { "complex" => lambda { ComplexDialog() }, "simple" => lambda do
        SimpleDialog()
      end }

      main_sequence = {
        "ws_start" => "simple", #TODO implement DecideComplexity
        "simple"   => {
          :next    => :finish,
          :abort   => :abort,
          :complex => "complex"
        },
        "complex"  => {
          :next   => :finish,
          :abort  => :abort,
          :simple => "simple"
        }
      }


      ret = Sequencer.Run(aliases, main_sequence)

      ret
    end

    def RunlevelSequence
      aliases = {
        "read"  => [lambda { ReadDialog() }, true],
        "main"  => lambda { MainSequence() },
        "write" => [lambda { WriteDialog() }, true]
      }

      sequence = {
        "ws_start" => "read",
        "read"     => { :abort => :abort, :next => "main" },
        "main"     => {
          :cancel => :abort,
          :abort  => :abort,
          :finish => "write"
        },
        "write"    => { :abort => :abort, :next => :next }
      }

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("runlevel")
      Wizard.HideBackButton
      Wizard.RestoreHelp(getHelpProgress)

      ret = Sequencer.Run(aliases, sequence)

      UI.CloseDialog
      ret
    end

    def RunlevelAutoSequence
      aliases = { "auto" => lambda { AutoDialog() } }

      auto_sequence = {
        "ws_start" => "auto",
        "auto"     => { :next => :finish, :abort => :abort }
      }


      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("runlevel")
      Wizard.HideBackButton
      Wizard.RestoreHelp(getHelpProgress)

      ret = Sequencer.Run(aliases, auto_sequence)

      UI.CloseDialog
      ret
    end
  end
end
