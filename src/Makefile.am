#
# Makefile.am for y2c_runlevel/src
#

myyncludedir = $(yncludedir)/runlevel

agent_SCRIPTS = 

scrconf_DATA = insserv_conf.scr

client_DATA =		\
	runlevel.ycp	\
	runlevel_auto.ycp 

myynclude_DATA =		\
	toposort.ycp \
	ui.ycp 

module_DATA = RunlevelEd.ycp

config_DATA = runlevel.y2cc

EXTRA_DIST = $(client_DATA) $(myynclude_DATA) $(config_DATA) $(agent_SCRIPTS) $(scrconf_DATA) $(module_DATA)

