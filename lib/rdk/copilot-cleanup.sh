#!/bin/sh

COPILOT_APP="/media/apps/co-pilot/"
CONNECTTV_APP="/media/apps/connecttv/"

COPILOT_RDM="/media/apps/rdm/downloads/co-pilot/"
CONNECTTV_RDM="/media/apps/rdm/downloads/connecttv/"

# remove pre-installed Co-Pilot RDM Packages
if [ -d "$COPILOT_APP" ]; then 
    echo "CoPilot RDM App found in $COPILOT_APP Cleaning up"
    rm -rf $COPILOT_APP;
fi

if [ -d "$COPILOT_RDM" ]; then
    echo "CoPilot RDM Packages found in $COPILOT_RDM Cleaning up"
    rm -rf $COPILOT_RDM;
fi

# remove pre-installed ConnectTV RDM Packages
if [ -d "$CONNECTTV_APP" ]; then
    echo "ConnectTV RDM App found in $CONNECTTV_APP Cleaning up"
    rm -rf $CONNECTTV_APP;
fi

if [ -d "$CONNECTTV_RDM" ]; then
    echo "ConnectTV RDM Packages found in $CONNECTTV_RDM Cleaning up"
    rm -rf $CONNECTTV_RDM;
fi