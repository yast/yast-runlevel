# Sources for runlevel

module_DATA = \
  modules/RunlevelEd.rb

client_DATA = \
  clients/runlevel_proposal.rb \
  clients/runlevel_auto.rb \
  clients/runlevel_finish.rb \
  clients/services_proposal.rb \
  clients/runlevel.rb

yncludedir = @yncludedir@/runlevel
ynclude_DATA = \
  include/runlevel/ui.rb \
  include/runlevel/toposort.rb \
  include/runlevel/wizard.rb

scrconf_DATA = \
  scrconf/insserv_conf.scr

schemafilesdir = $(schemadir)/autoyast/rnc
schemafiles_DATA = \
  autoyast-rnc/runlevels.rnc

desktop_DATA = \
  desktop/runlevel.desktop

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(scrconf_DATA) $(schemafiles_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common