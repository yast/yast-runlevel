#
# Makefile.am for y2c_runlevel/src
#

#crude:
TAGS_DEPENDENCIES = *.ycp
ETAGS_ARGS = $(TAGS_DEPENDENCIES)

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

desktop_DATA = runlevel.desktop

EXTRA_DIST = $(client_DATA) $(myynclude_DATA) $(config_DATA) $(agent_SCRIPTS) $(scrconf_DATA) $(module_DATA) $(desktop_DATA)

