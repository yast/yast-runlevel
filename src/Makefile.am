#
# Makefile.am for y2c_runlevel/src
#

agentsdir = $(YAST2DIR)/servers_non_y2
clientsdir = $(YAST2DIR)/clients
includedir = $(YAST2DIR)/include/runlevel
menudir = $(YAST2DIR)/menuentries
scrconfdir = $(YAST2DIR)/scrconf
modulesdir = $(YAST2DIR)/modules

agents_SCRIPTS = ag_initscripts

scrconf_DATA = initscripts.scr

clients_DATA =		\
	runlevel.ycp	\
	runlevel_auto.ycp \
	runlevel_write.ycp

include_DATA =		\
	ui.ycp

modules_DATA = Runlevel.ycp

menu_DATA = menuentry_runlevel.y2cc

EXTRA_DIST = $(clients_DATA) $(include_DATA) $(menu_DATA) $(agents_SCRIPTS) $(scrconf_DATA) $(modules_DATA)

