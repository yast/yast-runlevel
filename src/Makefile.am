#
# Makefile.am for y2c_runlevel/src
#

agentsdir = $(YAST2DIR)/servers_non_y2
clientsdir = $(YAST2DIR)/clients
includedir = $(YAST2DIR)/include/runlevel
menudir = $(YAST2DIR)/menuentries
scrconfdir = $(YAST2DIR)/scrconf

agents_SCRIPTS = ag_initscripts

scrconf_DATA = initscripts.scr

clients_DATA =		\
	runlevel.ycp

include_DATA =		\
	ui.ycp		\
	services.ycp	\
	starts.ycp

menu_DATA = menuentry_runlevel.ycp

EXTRA_DIST = $(clients_DATA) $(include_DATA) $(menu_DATA) $(agents_SCRIPTS) $(scrconf_DATA)

