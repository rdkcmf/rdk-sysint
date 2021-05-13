# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2016 RDK Management, LLC. All rights reserved.
# ============================================================================

WRKDIR		=	.
STAGING_DIR	=	staging_dir

SYS_CONF_DIR	=	/etc
SYS_USR_DIR     =       /usr
BASE_LIB_DIR	=	/lib
BASE_BIN_DIR    =       /bin

IPK_DIR		=	ipk
IPK_NAME	=	sysint.ipk

install:
	install -d $(STAGING_DIR)$(BASE_LIB_DIR)/rdk
	install -d $(STAGING_DIR)/HrvInitScripts
	install -m 0755 $(WRKDIR)/lib/rdk/* $(STAGING_DIR)$(BASE_LIB_DIR)/rdk
	install -m 0755 $(WRKDIR)/lib/rdk/hrvInitCleanup.sh $(STAGING_DIR)/HrvInitScripts/hrvInitCleanup.sh

	install -d $(STAGING_DIR)$(BASE_LIB_DIR)/systemd/system
	install -m 0755 $(WRKDIR)/systemd_units/*.service $(STAGING_DIR)$(BASE_LIB_DIR)/systemd/system
	install -m 0755 $(WRKDIR)/systemd_units/*.timer $(STAGING_DIR)$(BASE_LIB_DIR)/systemd/system

	install -d $(STAGING_DIR)$(SYS_CONF_DIR)
	install -m 0644 $(WRKDIR)/etc/*.json $(STAGING_DIR)$(SYS_CONF_DIR)
	install -m 0644 $(WRKDIR)/etc/*.properties $(STAGING_DIR)$(SYS_CONF_DIR)
	install -m 0644 $(WRKDIR)/etc/*.conf $(STAGING_DIR)$(SYS_CONF_DIR)

	install -d $(STAGING_DIR)$(SYS_USR_DIR)/bin
	install -m 0755 $(WRKDIR)/systemd_units/update_hosts.sh $(STAGING_DIR)$(SYS_USR_DIR)/bin/

	install -m 0755 $(WRKDIR)/etc/init.d/dump-backup-service $(STAGING_DIR)$(SYS_CONF_DIR)

	install -d $(STAGING_DIR)$(BASE_BIN_DIR)/
	cp $(WRKDIR)/lib/rdk/timestamp $(STAGING_DIR)$(BASE_BIN_DIR)/.
	
	if [ -d $(WRKDIR)/device/devspec/etc ]; then \
		install -m 0644 $(WRKDIR)/device/devspec/etc/*.properties $(STAGING_DIR)$(SYS_CONF_DIR) ;\
	fi

	if [ -d $(WRKDIR)/device/devspec/lib/rdk ]; then \
		install -m 0755 $(WRKDIR)/device/devspec/lib/rdk/* $(STAGING_DIR)$(BASE_LIB_DIR)/rdk ;\
	fi

	if [ -d $(WRKDIR)/device/lib/rdk/install ]; then \
		rm -rf $(WRKDIR)/device/lib/rdk/install ;\
	fi
	if [ -d $(WRKDIR)/device/lib/rdk ]; then \
		install -m 0755 $(WRKDIR)/device/lib/rdk/* $(STAGING_DIR)$(BASE_LIB_DIR)/rdk ;\
	fi

	if [ -f $(WRKDIR)/device/etc/videoPrefs.json ]; then \
		install -m 0755 $(WRKDIR)/device/etc/videoPrefs.json $(STAGING_DIR)$(SYS_CONF_DIR) ;\
	fi
	if [ -f $(WRKDIR)/device/etc/socks.conf ]; then \
		install -m 0755 $(WRKDIR)/device/etc/socks.conf $(STAGING_DIR)$(SYS_CONF_DIR) ;\
	fi
	if [ -f $(WRKDIR)/device/etc/env_setup.sh ]; then \
		install -m 0755 $(WRKDIR)/device/etc/env_setup.sh $(STAGING_DIR)$(SYS_CONF_DIR) ;\
	fi
	if [ -f $(WRKDIR)/device/etc/device.properties.wifi ]; then \
		install -m 0755 $(WRKDIR)/device/etc/device.properties.wifi $(STAGING_DIR)$(SYS_CONF_DIR) ;\
	fi
	install -m 0755 $(WRKDIR)/device/etc/*.properties $(STAGING_DIR)$(SYS_CONF_DIR)

	rm -rf $(STAGING_DIR)$(BASE_LIB_DIR)/rdk/bankSwitchStatusLogger.sh
	rm -rf $(STAGING_DIR)$(BASE_LIB_DIR)/rdk/lighttpd_utility.sh
	rm -rf $(STAGING_DIR)$(BASE_LIB_DIR)/rdk/uploadDumps.sh

	ln -sf /lib/rdk/rebootSTB.sh $(STAGING_DIR)
	ln -sf /lib/rdk/rebootNow.sh $(STAGING_DIR)

package_ipk: install
	tar -czvf $(IPK_DIR)/data.tar.gz -C $(STAGING_DIR) . 
	tar -czvf $(IPK_DIR)/control.tar.gz -C $(IPK_DIR) control postinst prerm 
	cd $(IPK_DIR) && ar cr $(IPK_NAME) debian-binary control.tar.gz data.tar.gz && cd -
