#
# Makefile.am for runlevel/src
#

#crude:
TAGS_DEPENDENCIES = *.ycp
ETAGS_ARGS = $(TAGS_DEPENDENCIES)

YCPCFLAGS = -I.

myyncludedir = @yncludedir@/runlevel

agent_SCRIPTS =

scrconf_DATA = insserv_conf.scr

client_DATA =			\
	runlevel.ycp		\
	runlevel_auto.ycp	\
	runlevel_proposal.ycp 

myynclude_DATA =		\
	wizard.ycp		\
	toposort.ycp		\
	ui.ycp

module_DATA = RunlevelEd.ycp

desktop_DATA = runlevel.desktop

runlevel:
	ln -sf . runlevel

ycpchook = runlevel

EXTRA_DIST = $(client_DATA) $(myynclude_DATA) $(agent_SCRIPTS) $(scrconf_DATA) $(module_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common
