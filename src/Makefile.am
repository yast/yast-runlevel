#
# Makefile.am for y2c_runlevel/src
#

myyncludedir = $(yncludedir)/runlevel

agent_SCRIPTS = ag_initscripts

scrconf_DATA = initscripts.scr

client_DATA =		\
	runlevel.ycp	\
	runlevel_auto.ycp \
	runlevel_write.ycp

myynclude_DATA =		\
	ui.ycp

module_DATA = Runlevel.ycp

config_DATA = runlevel.y2cc

EXTRA_DIST = $(client_DATA) $(myynclude_DATA) $(config_DATA) $(agent_SCRIPTS) $(scrconf_DATA) $(module_DATA)

