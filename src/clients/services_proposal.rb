# encoding: utf-8

# File:	clients/services_proposal.ycp
# Package:	Services configuration
# Summary:	Services configuration proposal
# Authors:	Lukas Ocilka <locilka@suse.cz>
# See:		FATE #305583: Start CIMOM by default
#
# $Id$
module Yast
  class ServicesProposalClient < Client
    def main

      textdomain "runlevel"

      Yast.import "RunlevelEd"
      Yast.import "Progress"
      Yast.import "ProductControl"
      Yast.import "ProductFeatures"
      Yast.import "Service"
      Yast.import "Linuxrc"
      Yast.import "Report"
      Yast.import "Package"
      Yast.import "SuSEFirewall"

      #**
      #  <globals>
      #      <!-- Used in services proposal -->
      #      <services_proposal config:type="list">
      #          <!-- FATE #305583: Start CIMOM by default -->
      #          <service>
      #              <label_id>service_sfcb</label_id>
      #              <!-- space-separated names of services as found in /etc/init.d/ -->
      #              <service_names>sfcb</service_names>
      #              <!-- space-separated SuSEfirewall2 services as found in /etc/sysconfig/SuSEfirewall2.d/services/ -->
      #              <firewall_plugins>sblim-sfcb</firewall_plugins>
      #              <!-- Should be the service proposed as enabled by default? If not defined, false is used. -->
      #              <enabled_by_default config:type="boolean">true</enabled_by_default>
      #              <!-- list of packages to be installed before the services is enabled -->
      #              <packages>sblim-sfcb</packages>
      #          </service>
      #      </services_proposal>
      #  </globals>
      #
      #  <texts>
      #      <service_sfcb><label>CIM Service</label></service_sfcb>
      #  </texts>

      # Client operates differently in automatic configuration
      @automatic_configuration = false

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Services proposal started")
      Builtins.y2milestone("Arguments: %1", WFM.Args)

      @func = Convert.to_string(WFM.Args(0))
      @param = Convert.to_map(WFM.Args(1))
      @ret = {}

      @automatic_configuration = Ops.get_boolean(
        @param,
        "AutomaticConfiguration",
        false
      ) == true

      # create a textual proposal
      if @func == "MakeProposal"
        @progress_orig = Progress.set(false)
        @force_reset = Ops.get_boolean(@param, "force_reset", false)

        ReadCurrentConfiguration(@force_reset)

        @ret = {
          "preformatted_proposal" => GetProposalSummary(),
          "warning_level"         => :warning,
          "warning"               => nil,
          "links"                 => RunlevelEd.services_proposal_links,
          "help"                  => GetHelpText()
        }
        Builtins.y2internal("RETURNED %1", @ret)

        Progress.set(@progress_orig)
      # run the module
      elsif @func == "AskUser"
        @chosen_id = Ops.get(@param, "chosen_id")
        Builtins.y2milestone(
          "Services Proposal wanted to change with id %1",
          @chosen_id
        )

        # When user clicks on any clickable <a href> in services proposal,
        # one of these actions is called
        if Ops.is_string?(@chosen_id) &&
            Builtins.regexpmatch(
              Builtins.tostring(@chosen_id),
              "^toggle_service_[[:digit:]]+$"
            )
          Builtins.y2milestone("Toggling service: %1", @chosen_id)
          ToggleService(Builtins.tostring(@chosen_id))
          @ret = { "workflow_sequence" => :next } 

          # Change the services settings in usual configuration dialogs
        else
          Builtins.y2warning("ID %1 is not handled", @chosen_id)
          @ret = { "workflow_sequence" => :next }
        end
      # create titles
      elsif @func == "Description"
        @ret = {
          # RichText label
          "rich_text_title" => _("Services"),
          # Menu label
          "menu_title"      => _("&Services"),
          "id"              => "services"
        }
      # write the proposal
      elsif @func == "Write"
        WriteSettings()
      else
        Builtins.y2error("unknown function: %1", @func)
      end

      # Finish
      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("Services proposal finished")
      Builtins.y2milestone("----------------------------------------")
      deep_copy(@ret) 

      # EOF
    end

    def GetCurrentStatus(services)
      services = deep_copy(services)
      if services == nil || services == []
        Builtins.y2error("Services not defined")
        return false
      end

      ret = true

      Builtins.foreach(services) do |service|
        if Service.Status(service) != 0 || Service.Enabled(service) != true
          ret = false
          Builtins.y2milestone(
            "Service %1 is not running or it is disabled",
            service
          )
          raise Break
        end
      end

      ret
    end

    def ReadCurrentConfiguration(force)
      if RunlevelEd.configuration_already_loaded != true || force == true
        Builtins.y2milestone("Loading the current runlevel configuration")
        progress_orig = Progress.set(false)

        RunlevelEd.Read
        RunlevelEd.configuration_already_loaded = true

        SuSEFirewall.Read

        tmp_services_settings = Convert.convert(
          ProductFeatures.GetFeature("globals", "services_proposal"),
          :from => "any",
          :to   => "list <map>"
        )

        if tmp_services_settings == nil
          Builtins.y2error("No globals->services_proposal defined")
        else
          RunlevelEd.services_proposal_settings = []
          RunlevelEd.services_proposal_links = []
          counter = -1

          Builtins.foreach(tmp_services_settings) do |one_service2|
            # service_names requiered
            if !Builtins.haskey(one_service2, "service_names") ||
                Ops.get_string(one_service2, "service_names", "") == nil
              Builtins.y2error(
                "Invalid service_names in %1, ignoring this service.",
                one_service2
              )
              next
            end
            services = Builtins.splitstring(
              Ops.get_string(one_service2, "service_names", ""),
              " ,"
            )
            if services == nil || Ops.less_than(Builtins.size(services), 1)
              Builtins.y2error(
                "Invalid service_names in %1, ignoring this service.",
                one_service2
              )
              next
            end
            # firewall_plugins are not required but they must be correct anyway
            if Builtins.haskey(one_service2, "firewall_plugins") &&
                Ops.get_string(one_service2, "firewall_plugins", "") == nil
              Builtins.y2error(
                "Invalid firewall_plugins in %1, ignoring this service.",
                one_service2
              )
              next
            end
            firewall_plugins = Builtins.splitstring(
              Ops.get_string(one_service2, "firewall_plugins", ""),
              " ,"
            )
            # default is: disabled
            enabled_by_default = false
            # if defined, it must be boolean
            if Builtins.haskey(one_service2, "enabled_by_default")
              if Ops.get_boolean(one_service2, "enabled_by_default", false) == true ||
                  Ops.get_boolean(one_service2, "enabled_by_default", false) == false
                enabled_by_default = Ops.get_boolean(
                  one_service2,
                  "enabled_by_default",
                  false
                )
              else
                Builtins.y2error(
                  "Invalid enabled_by_default in %1, using: %2.",
                  one_service2,
                  enabled_by_default
                )
              end
            end
            # fallback for label
            label = Builtins.mergestring(services, ", ")
            if Builtins.haskey(one_service2, "label_id") &&
                Ops.get_string(one_service2, "label_id", "") == nil ||
                Ops.get_string(one_service2, "label_id", "") == ""
              Builtins.y2error(
                "Invalid label_id in %1, using %2",
                one_service2,
                label
              )
            else
              tmp_label = ProductControl.GetTranslatedText(
                Ops.get_string(one_service2, "label_id", "")
              )
              if tmp_label == nil || tmp_label == ""
                label = Ops.get_string(one_service2, "label_id", "")
                Builtins.y2error(
                  "Unable to translate %1",
                  Ops.get_string(one_service2, "label_id", "")
                )
              else
                label = tmp_label
              end
            end
            # packages are not required but they must be correct anyway
            if Builtins.haskey(one_service2, "packages") &&
                Ops.get_string(one_service2, "packages", "") == nil
              Builtins.y2error(
                "Invalid packages in %1, ignoring this service.",
                one_service2
              )
              next
            end
            packages = Builtins.splitstring(
              Ops.get_string(one_service2, "packages", ""),
              " ,"
            )
            one_service2 = {
              "label"              => label,
              "services"           => services,
              "firewall_plugins"   => firewall_plugins,
              # override the default status according to the current status
              "enabled"            => enabled_by_default == false ?
                GetCurrentStatus(services) :
                enabled_by_default,
              "enabled_by_default" => enabled_by_default,
              "packages"           => packages
            }
            RunlevelEd.services_proposal_settings = Builtins.add(
              RunlevelEd.services_proposal_settings,
              one_service2
            )
            counter = Ops.add(counter, 1)
            RunlevelEd.services_proposal_links = Builtins.add(
              RunlevelEd.services_proposal_links,
              Builtins.sformat("toggle_service_%1", counter)
            )
          end

          Builtins.y2milestone(
            "Default settings loaded: %1",
            RunlevelEd.services_proposal_settings
          )
        end

        Progress.set(progress_orig)
      end

      nil
    end

    def GetProposalSummary
      ret = ""

      firewall_is_enabled = SuSEFirewall.IsEnabled

      counter = -1
      Builtins.foreach(RunlevelEd.services_proposal_settings) do |one_service|
        counter = Ops.add(counter, 1)
        message = ""
        # There are some ports (services) required to be open and firewall is enabled
        if Ops.greater_than(
            Builtins.size(Ops.get_list(one_service, "firewall_plugins", [])),
            0
          ) && firewall_is_enabled
          if Ops.get_boolean(one_service, "enabled", false) == true
            message = Builtins.sformat(
              _(
                "Service <i>%1</i> will be <b>enabled</b> and ports in the firewall will be open <a href=\"%2\">(disable)</a>"
              ),
              Ops.get_string(one_service, "label", ""),
              Builtins.sformat("toggle_service_%1", counter)
            )
          else
            message = Builtins.sformat(
              _(
                "Service <i>%1</i> will be <b>disabled</b> and ports in firewall will be closed <a href=\"%2\">(enable)</a>"
              ),
              Ops.get_string(one_service, "label", ""),
              Builtins.sformat("toggle_service_%1", counter)
            )
          end
        else
          if Ops.get_boolean(one_service, "enabled", false) == true
            message = Builtins.sformat(
              _(
                "Service <i>%1</i> will be <b>enabled</b> <a href=\"%2\">(disable)</a>"
              ),
              Ops.get_string(one_service, "label", ""),
              Builtins.sformat("toggle_service_%1", counter)
            )
          else
            message = Builtins.sformat(
              _(
                "Service <i>%1</i> will be <b>disabled</b> <a href=\"%2\">(enable)</a>"
              ),
              Ops.get_string(one_service, "label", ""),
              Builtins.sformat("toggle_service_%1", counter)
            )
          end
        end
        ret = Ops.add(Ops.add(Ops.add(ret, "<li>"), message), "</li>\n")
      end

      Ops.add(Ops.add("<ul>", ret), "</ul>")
    end

    # Changes the proposed value.
    # Enables disabled service and vice versa.
    def ToggleService(chosen_id)
      if !Builtins.regexpmatch(chosen_id, "^toggle_service_[[:digit:]]+$")
        Builtins.y2error("Erroneous ID: %1", chosen_id)
        return false
      end

      chosen_id = Builtins.regexpsub(
        chosen_id,
        "^toggle_service_([[:digit:]])+$",
        "\\1"
      )
      if chosen_id == nil
        Builtins.y2error("Cannot get ID from: %1", chosen_id)
        return false
      end

      _ID = Builtins.tointeger(chosen_id)
      if Ops.get(RunlevelEd.services_proposal_settings, _ID, {}) == nil ||
          Ops.get(RunlevelEd.services_proposal_settings, _ID, {}) == {}
        Builtins.y2error(
          "Cannot find service ID: %1 in %2",
          _ID,
          RunlevelEd.services_proposal_settings
        )
        return false
      end

      if Ops.get_boolean(
          RunlevelEd.services_proposal_settings,
          [_ID, "enabled"],
          false
        ) == nil
        Builtins.y2error(
          "Service %1 is neither enabled not disabled",
          Ops.get(RunlevelEd.services_proposal_settings, _ID, {})
        )
        return false
      end

      Ops.set(
        RunlevelEd.services_proposal_settings,
        [_ID, "enabled"],
        !Ops.get_boolean(
          RunlevelEd.services_proposal_settings,
          [_ID, "enabled"],
          false
        )
      )
      Builtins.y2milestone(
        "Service ID: %1 is enabled: %2",
        _ID,
        Ops.get_boolean(
          RunlevelEd.services_proposal_settings,
          [_ID, "enabled"],
          false
        )
      )
      true
    end

    # Some services should not be stopped, in respect to the currently
    # used installation method.
    def CanCloseService(service_name)
      return false if Linuxrc.vnc && service_name == "xinetd"
      return false if Linuxrc.usessh && service_name == "sshd"

      true
    end

    def DisableAndStopServices(services)
      services = deep_copy(services)
      Builtins.foreach(services) do |one_name|
        if CanCloseService(one_name) != true
          Builtins.y2warning("Service %1 must no be closed now", one_name)
        end
        # Service is currently enabled or running
        if Service.Status(one_name) == 0 || Service.Enabled(one_name)
          Builtins.y2milestone("Stopping and disabling service: %1", one_name)
          Service.RunInitScriptWithTimeOut(one_name, "stop")
          Service.Disable(one_name)
        end
      end

      nil
    end

    # Opens ports using firewall services got as parameter.
    # Services are actually in format "service_name", not
    # "service:service_name".
    def OpenPortInFirewall(firewall_plugins)
      firewall_plugins = deep_copy(firewall_plugins)
      firewall_plugins = Builtins.maplist(firewall_plugins) do |one_plugin|
        Builtins.sformat("service:%1", one_plugin)
      end

      # All interfaces known to firewall
      interfaces = Builtins.maplist(SuSEFirewall.GetAllKnownInterfaces) do |one_interface|
        Ops.get_string(one_interface, "id", "")
      end

      interfaces = [] if interfaces == nil
      interfaces = Builtins.filter(interfaces) do |one_interface|
        one_interface != nil && one_interface != ""
      end
      Builtins.y2milestone("All known fw interfaces: %1", interfaces)

      # Services will be open in these zones
      used_fw_zones = []

      # All zones used by all interfaces (if any interface is known)
      if Ops.greater_than(Builtins.size(interfaces), 0)
        used_fw_zones = SuSEFirewall.GetZonesOfInterfacesWithAnyFeatureSupported(
          interfaces
        ) 
        # Opening for all zones otherwise
      else
        used_fw_zones = SuSEFirewall.GetKnownFirewallZones
      end

      Builtins.y2milestone(
        "Firewall zones: %1 for enabling services: %2, ",
        used_fw_zones,
        firewall_plugins
      )
      SuSEFirewall.SetServicesForZones(firewall_plugins, used_fw_zones, true)
    end

    # Checks which packages from those got as a list are not installed.
    # Returns list of not installed packages.
    # Eventually reports unavailable packages one by one.
    def NotInstalledPackages(packages)
      packages = deep_copy(packages)
      not_installed = []

      Builtins.foreach(packages) do |one_package|
        if Package.Installed(one_package) != true
          if Package.Available(one_package) != true
            Report.Error(
              Builtins.sformat(
                _("Required package %1 is not available for installation."),
                one_package
              )
            )
          end
          not_installed = Builtins.add(not_installed, one_package)
        end
      end

      Builtins.y2milestone("Not installed packages: %1", not_installed)
      deep_copy(not_installed)
    end

    def WriteSettings
      ret = true

      progress_orig = Progress.set(false)
      firewall_is_enabled = SuSEFirewall.IsEnabled

      counter = -1
      Builtins.foreach(RunlevelEd.services_proposal_settings) do |one_service|
        counter = Ops.add(counter, 1)
        services = Ops.get_list(one_service, "services", [])
        firewall_plugins = Ops.get_list(one_service, "firewall_plugins", [])
        packages = Ops.get_list(one_service, "packages", [])
        # Service should be disabled
        if Ops.get_boolean(one_service, "enabled", false) != true
          Builtins.y2milestone("Service %1 should not be enabled", counter)
          DisableAndStopServices(services)
          # next service
          next
        end
        # Some packages have to be installed first
        if Ops.greater_than(Builtins.size(packages), 0)
          packages_installed = nil

          # Returns which packages from list are not installed
          packages = NotInstalledPackages(packages)

          # All are installed
          if packages == []
            packages_installed = true 
            # Install them
          else
            packages_installed = Package.DoInstall(packages)
          end

          if packages_installed == true
            Builtins.y2milestone(
              "Required packages for %1 are installed",
              counter
            )
          else
            Report.Error(
              _(
                "Installation of required packages has failed,\nenabling and starting the services may also fail."
              )
            )
          end
        end
        # Enabling services
        if !RunlevelEd.EnableServices(services)
          ret = false
          next
        end
        # Starting services
        if !RunlevelEd.StartServicesWithDependencies(services)
          ret = false
          # next service
          next
        end
        # Opening ports in firewall (only if firewall is enabled)
        if firewall_is_enabled == true &&
            Ops.greater_than(Builtins.size(firewall_plugins), 0)
          OpenPortInFirewall(firewall_plugins)
        end
      end

      # Finally, write the firewall settings
      SuSEFirewall.Write

      Progress.set(progress_orig)

      ret
    end

    def GetHelpText
      if RunlevelEd.services_proposal_settings == nil ||
          RunlevelEd.services_proposal_settings == []
        # a help text, not very helpful though
        return _(
          "<p><big><b>Services</b></big><br>\nThe current setup does not provide any functionality now.</p>"
        )
      end

      # a help text, part 1
      _(
        "<p><big><b>Services</b></big><br>\n" +
          "This installation proposal allows you to start and enable a service from the \n" +
          "list of services.</p>\n"
      ) +
        # a help text, part 2
        _(
          "<p>It may also open ports in the firewall for a service if firewall is enabled\nand a particular service requires opening them.</p>\n"
        )
    end
  end
end

Yast::ServicesProposalClient.new.main
