#!bin/sh

COPILOT_APP="/media/apps/co-pilot/"
CONNECTTV_APP="/media/apps/connecttv/"

COPILOT_RDM="/media/apps/rdm/downloads/co-pilot/"
CONNECTTV_RDM="/media/apps/rdm/downloads/connecttv/"

# remove pre-installed Co-Pilot RDM Packages
if [ -d "$COPILOT_APP" ]; then rm -rf $COPILOT_APP; fi
if [ -d "$COPILOT_RDM" ]; then rm -rf $COPILOT_RDM; fi

# remove pre-installed ConnectTV RDM Packages
if [ -d "$CONNECTTV_APP" ]; then rm -rf $CONNECTTV_APP; fi
if [ -d "$CONNECTTV_RDM" ]; then rm -rf $CONNECTTV_RDM; fi
