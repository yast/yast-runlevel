#! /bin/bash
# $Id$
# required: pdb-commandline.rpm
#

SX=scripts
:> $SX.ycp.out
exec > $SX.ycp.out

# no leading slash
DIR=etc/init.d

function extract() {
    pdb query --filter "rpmdir:/$DIR" --attribs packname > $SX-pkgs

    mv -f $DIR/* $DIR.bak
    sort $SX-pkgs | while read pkg; do
	rpm2cpio /work/CDs/all/full-i386/suse/*/$pkg.rpm \
	| cpio -idvm --no-absolute-filenames "$DIR/*" "./$DIR/*"
    done
}

extract

echo -n "// Generated on "
LANG=C date
# comment out the nil reply to the agent initialization
echo -n "//"
# Use the agent to parse the config files
{
    echo "InitScripts (\"$DIR\")"
    echo "Read (.comments)"
} | /usr/lib/YaST2/servers_non_y2/ag_initscripts
