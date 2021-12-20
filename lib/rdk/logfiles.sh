#!/bin/sh
##############################################################################
# If not stated otherwise in this file or this component's LICENSE file the
# following copyright and licenses apply:
#
# Copyright 2020 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##############################################################################


. /etc/include.properties
. /etc/device.properties

emmcDebugLog="emmc_debug.log"
emmcHealthLog="eMMC_diag.log"
xreLog="receiver.log"
ttsLog="tts_engine.log"
cecLog="cec_log.txt"
cecLogsBackup="cec_log.txt.*"
xreLogsBackup="receiver.log.*"
ttsLogsBackup="tts_engine.log.*"
receiverMON="ReceiverMON.txt"
runXreLog="runXRE_log.txt"
runXreLogsBackup="runXRE_log.txt.*"
greenpeakLog="greenpeak.log"
greenpeakLogsBackup="greenpeak.log.*"
appStatusLog="app_status.log"
appStatusLogsBackup="app_status.log.*"
gpInitLog="gp_init.log"
gpInitLogsBackup="gp_init.log.*"
#demsg Logs
dmesgLog="messages_printk.txt"
dmesgLogsBackup="messages_printk_bak.txt.*"
sysLog="messages.txt"
ntpLog="ntp.log"
sysLogsBackup="messages.txt.*"
ntpLogsBackup="ntp.log.*"
sysDmesgLog="messages-dmesg.txt"
sysDmesgLogsBackup="messages-dmesg.txt.*"
startupDmesgLog="startup_stdout_log.txt"
startupDmesgLogsBackup="startup_stdout_log.txt.*"
lighttpdErrorLog="lighttpd.error.log"
lighttpdErrorLogsBackup="lighttpd.error.log.*"
lighttpdAccessLog="lighttpd.access.log"
lighttpdAccessLogsBackup="lighttpd.access.log.*"
dcmLog="dcmscript.log"
dcmLogsBackup="dcmscript.log.*"
dnsmasqLog="dnsmasq.log"
dnsmasqLogsBackup="dnsmasq.log.*"
uiLog="uimgr_log.txt"
uiLogsBackup="uimgr_log.txt.*"
storagemgrLog="storagemgr.log"
storagemgrLogsBackup="storagemgr.log.*"
speedtestLog="speedtest_log.txt"
speedtestLogsBackup="speedtest_log.txt.*"
rf4ceLog="rf4ce_log.txt"
rf4ceLogsBackup="rf4ce_log.txt.*"
ctrlmLog="ctrlm_log.txt"
ctrlmLogsBackup="ctrlm_log.txt.*"
xDiscoveryLog="xdiscovery.log"
xDiscoveryLogsBackup="xdiscovery.log.*"
xDiscoveryListLog="xdiscoverylist.log"
xDiscoveryListLogsBackup="xdiscoverylist.log.*"
hdmiLog="hdmi_log.txt"
rebootLog="reboot.log"
rebootInfoLog="rebootInfo.log"
ueiLog="uei_init.log"
if [ "$WHITEBOX_ENABLED" == "true" ]; then
wbLog="wbdevice.log"
fi
swUpdateLog="swupdate.log"
topLog="top_log.txt"
topLogsBackup="top_log.txt.*"
mocaLog="mocalog.txt"
coreLog="coredump.log"
coreDumpLog="core_log.txt"
coreDumpLogsBackup="core_log.txt.*"
version="version.txt"
fusionDaleLog="fusiondale_log.txt"
socProvisionLog="socprov.log"
socProvisionLogsBackup="socprov.log.*"
socProvisionCryptoLog="socprov-crypto.log"
socProvisionCryptoLogsBackup="socprov-crypto.log.*"
applicationsLog="applications.log"
applicationsLogsBackup="applications.log.*"
gstreamerLog="gst-cleanup.log"
systemLog="system.log"
systemLogsBackup="system.log.*"
bootUpLog="bootlog"
bootUpLogsBackup="bootlog.*"
resetLog="Reset.txt"
resetLogsBackup="Reset.txt.*"
backUpDumpLog="backupCoreDumpLog.txt"
gpLog="gp.log"
gpLogsBackup="gp.log.*"
diskInfoLog="diskInfo.txt"
diskEventsLog="diskEvents.txt"

rmfLog="rmfstr_log.txt"
rmfLogsBackup="rmfstr_log.txt.*"
podLog="pod_log.txt"
podLogsBackup="pod_log.txt.*"
vodLog="vodclient_log.txt"
vodLogsBackup="vodclient_log.txt.*"
rstreamFdLog="rstreamer_fdlist.txt"

recorderLog="/opt/rec_debug.log"
fdsLog="fds.log"
fdsLogsBackup="fds.log.*"
trmLog="trm.log"
trmMgrLog="trmmgr.log"
trmLogsBackup="trm.log.*"
trmMgrLogsBackup="trmmgr.log.*"
vlThreadLog="vlthreadanalyzer_log.txt"
vlThreadLogsBackup="vlthreadanalyzer_log.txt.*"
xDeviceLog="xdevice.log"
xDeviceLogsBackup="xdevice.log.*"
authServiceLog="authservice.log"
cardProvisionCheckLog="card-provision-check.log"
ipdnlLog="ipdllogfile.txt"
diskCleanupInfoLog="disk_cleanup_info.log"
topOsalLog="top_osal.txt"
topOsalLogsBackup="top_osal.txt.*"
mocaStatusLog="mocaStatus.log"
mocaStatusLogsBackup="mocaStatus.log.*"
mocaDriverLog="moca-driver.log"
mocaDriverLogsBackup="moca-driver.log.*"
mocaServiceLog="mocaService.log"
mocaServiceLogsBackup="mocaService.log.*"
mfrLog="mfrlib_log.txt"
mfrLogsBackup="mfrlib_log.txt.*"
mfrLogRdk="mfr_log.txt"
mfrLogsRdkBackup="mfr_log.txt.*"
adobeCleanupLog="cleanAdobe.log"
diskCleanupLog="disk_cleanup.log"
diskCleanupLogsBackup="disk_cleanup.log.*"
decoderStatusLog="procStatus.log"
decoderStatusLogsBackup="procStatus.log.*"
recorderLog="/opt/rec_debug.log"
psLogsBackup="ps_out.txt*"
netsrvLog="netsrvmgr.log"
netsrvLogsBackup="netsrvmgr.log.*"
fogLog="fog.log"
fogLogsBackup="fog.log.*"
hddStatusLog="diskinfo.log"
hddStatusLogsBackup="diskinfo.log.*"
xiRecoveryLog="discoverV4Client.log"
xiRecoveryLogsBackup="discoverV4Client.log.*"
bluetoothLog="btmgrlog.txt"
bluetoothLogBackup="btmgrlog.txt.*"
bluezLog="bluez.log"
bluezLogBackup="bluez.log.*"
mountLog="mount_log.txt"
mountLogBackup="mount_log.txt.*"
rbiDaemonLog="rbiDaemon.log"
rbiDaemonLogsBackup="rbiDaemon.log.*"
rfcLog="rfcscript.log"
rfcLogsBackup="rfcscript.log.*"
tlsLog="tlsError.log"
tlsLogsBackup="tlsError.log.*"
pingTelemetryLog="ping_telemetry.log"
pingTelemetryLogsBackup="ping_telemetry.log.*"
deviceDetailsLog="device_details.log"
hwselfLog="hwselftest.log"
hwselfLogsBackup="hwselftest.log.*"
wpeframeworkLog="wpeframework.log"
wpeframeworkLogsBackup="wpeframework.log.*"
residentAppLog="residentapp.log"
residentAppLogsBackup="residentapp.log.*"
servicenumberLog="servicenumber.log"
servicenumberLogsBackup="servicenumber.log.*"
appmanagerLog="appmanager.log"
appmanagerLogsBackup="appmanager.log.*"
easPcapFile="eas.pcap"
mocaPcapFile="moca.pcap"
audiocapturemgrLogs="audiocapturemgr.log"
nlmonLog="nlmon.log"
nlmonLogsBackup="nlmon.log.*"
appsRdmLog="rdm_status.log"
rebootReasonLog="rebootreason.log"
rebootReasonLogsBackup="rebootreason.log.*"
dropbearLog="dropbear.log"
dropbearLogsBackup="dropbear.log.*"
xdialLog="xdial.log"
xdialLogsBackup="xdial.log.*"
btrLeAppMgrLog="btrLeAppMgr.log"
btrLeAppMgrLogsBackup="btrLeAppMgr.log.*"
dibblerclientLog="dibbler-client.log"
dibblerclientLogsBackup="dibbler-client.log.*"
ecfsLog="ecfs.txt"
ecfsLogsBackup="ecfs.txt.*"
iptablesLog="iptables.log"
iptablesLogsBackup="iptables.log.*"
perfmonstatusLog="perfmonstatus.log"
perfmonstatusLogsBackup="perfmonstatus.log.*"
rdkmilestonesLog="rdk_milestones.log"
rdkmilestonesLogsBackup="rdk_milestones.log.*"
stunnelLog="stunnel.log"
stunnelLogsBackup="stunnel.log.*"
tr69HostIfLog="tr69hostif.log"
tr69HostIfLogsBackup="tr69hostif.log.*"
cgrpmemoryLog="cgrpmemory.log"
cgrpmemoryLogsBackup="cgrpmemory.log.*"
cgrmemorytestLog="cgrmemorytest.log"
cgrmemorytestLogsBackup="cgrmemorytest.log.*"
hdcpLog="hdcp.log"
hdcpLogsBackup="hdcp.log.*"
threadLog="thread.log"
threadLogsBackup="thread.log.*"
LastUrlLog="last_url.txt"
LastUrlLogsBackup="last_url.txt.*"
CrashedUrlLog="crashed_url.txt"
CrashedUrlLogsBackup="crashed_url.txt.*"
nslookupLog="nslookup.log"
nslookupLogsBackup="nslookup.log.*"
tracerouteLog="traceroute.log"
tracerouteLogsBackup="traceroute.log.*"
traceroute6Log="traceroute6.log"
traceroute6LogsBackup="traceroute6.log.*"
lightsleepLog="lightsleep.log"
pathFailLog="path_fail.log"
pathFailLogsBackup="path_fail.log.*"
rtroutedLog="rtrouted.log"
rtroutedLogsBackup="rtrouted.log.*"
hwselfresultsLog="hwselftest.results"
hwselfresultsLogsBackup="hwselftest.results.*"
lxyLog="lxy.log"
lxyLogsBackup="lxy.log.*"
webpavideoLog="webpavideo.log"
webpavideoLogsBackup="webpavideo.log.*"
cronjobLog="cronjobs_update.log"
cronjobLogsBackup="cronjobs_update.log.*"
logrotateLog="logrotate.log"
logrotateLogsBackup="logrotate.log.*"
systimemgrLog="systimemgr.log"
systimemgrLogsBackup="systimemgr.log.*"

if [ "$CONTAINER_SUPPORT" == "true" ];then
    xreLxcLog="xre.log"
    xreLxcLogsBackup="xre.log.*"
    xreLxcApplicationsLog="xre-applications.log"
    xreLxcApplicationsLogsBackup="xre-applications.log.*"
fi
if [ "$DOBBY_ENABLED" == "true" ];then
    dobbyLog="dobby.log"
    dobbyLogsBackup="dobby.log.*"
fi
if [ "$SOC" = "BRCM" ];then
      nxSvrLog="nxserver.log"
      nxSvrLogsBackup="nxserver.log.*"
      if [ "$PROC_STATUS_LOG_SUPPORT" = "true" ];then
          procStatusLog="proc-status-logger.log"
          procStatusLogsBackup="proc-status-logger.log.*"
      fi
fi

if [ "$SOC" = "AMLOGIC" ];then
	AudioServerLog="audioserver.log"
	AudioServerLogsBackup="audioserver.log.*"
	TvServerLog="tvservice.log"
	TvServerLogsBackup="tvservice.log.*"
	PqserverLog="pqserver.log"
	PqserverLogsbackup="pqserver.log.*"
	Dolbyms12Log="dolby_ms12.log"
	Dolbyms12Logsbackup="dolby_ms12.log.*"
fi

if [ "$SOC" = "RTK" ];then
        realtekDmesgKernelLog="dmesg-ramoops-0.log"
        realtekConsoleKernelLog="console-ramoops-0.log"
        realtekDmesgKernelLogBackup="dmesg-ramoops-0.log.*"
        realtekConsoleKernelLogBackup="console-ramoops-0.log.*"
        realtekServiceLog="rtk_service.log"
        realtekServiceLogBackup="rtk_service.log.*"
        realtekFWLog="rtk_fw.log"
        realtekFWLogBackup="rtk_fw.log.*"
        realtekAFWLicenseCheckLog="rtk_afw_license_check.log"
        realtekAFWLicenseCheckLogBackup="rtk_afw_license_check.log.*"
fi

if [ "$DEVICE_NAME" = "PLATCO" ]; then
        factoryCommsLog="factoryComms.log"
        factoryCommsLogsbackup="factoryComms.log.*"
fi

if [ "$MEDIARITE" == "true" ];then
	MediaRiteLog="mediarite.log"
	MediaRiteLogsBackup="mediarite.log.*"
fi

if [ "$DEVICE_TYPE" != "mediaclient" ]; then
     riLog="ocapri_log.txt"
     riLogsBackup="ocapri_log.txt.*"
     mpeosmainMON="mpeos-mainMON.txt"
     mpeosRebootLog="/opt/mpeos_reboot_log.txt"
     cardStatusLog="card_status.log"
     heapDmpLog="jvmheapdump.txt"
     rfStatisticsLog="rf_statistics_log.txt"
     ablReasonLog="ABLReason.txt"
     ecmLog="messages-ecm.txt"
     ecmLogsBackup="messages-ecm.txt.*"
     pumaLog="messages-puma.txt"
     pumaLogsBackup="messages-puma.txt.*"
     xfsdmesgLog="xfs_mount_dmesg.txt"
     snmpdLog="snmpd.log"
     snmpdLogsBackup="snmpd.log.*"
     upstreamStatsLog="upstream_stats.log"
     upstreamStatsLogsBackup="upstream_stats.log.*"
     dibblerLog="dibbler.log"
     dibblerLogsBackup="dibbler.log.*"
     parodusLog="parodus.log"
     parodusLogsBackup="parodus.log.*"
     cpuprocanalyzerLog="cpuprocanalyzer.log"
     cpuprocanalyzerLogsBackup="cpuprocanalyzer.log.*"
     namedLog="named.log"
     namedLogsBackup="named.log.*"
     dnsqueryLog="dnsquery.log"
     dnsqueryLogsBackup="dnsquery.log.*"
else
     ablReasonLog="ABLReason.txt"
     wifiTelemetryLog="wifi_telemetry.log"
     wifiTelemetryLogBackup="wifi_telemetry.log.*"
     tr69Log="tr69Client.log"
     tr69AgentLog="tr69agent.log"
     tr69AgentLogBackup="tr69agent.log.*"
     gatewayLog="gwSetupLogs.txt"
     ipSetupLog="ipSetupLogs.txt"
     tr69DownloadLog="tr69FWDnld.log"
     tr69AgentHttpLog="tr69agent_HTTP.log"
     tr69AgentHttpLogsBackup="tr69agent_HTTP.log.*"
     tr69AgentSoapLog="tr69agent_SoapDebug.log"
     tr69AgentSoapLogsBackup="tr69agent_SoapDebug.log.*"
     parodusLog="parodus.log"
     parodusLogsBackup="parodus.log.*"
     ConnectionStatusLog="ConnectionStats.txt"
     ConnectionStatusLogsBackup="ConnectionStats.txt.*"
     cpuprocanalyzerLog="cpuprocanalyzer.log"
     cpuprocanalyzerLogsBackup="cpuprocanalyzer.log.*"
     namedLog="named.log"
     namedLogsBackup="named.log.*"
     dnsqueryLog="dnsquery.log"
     dnsqueryLogsBackup="dnsquery.log.*"
     if [ "$SKY_EPG_SUPPORT" == "true" ] || [ "$SKY_SERVICE_LOGGING" == "true" ]; then
        skyMessagesLog="sky-messages.log"
        skyMessagesLogBackup="sky-messages.log.*"
     fi
     subttxrendappLog="subttxrend-app.log"
     subttxrendappLogBackup="subttxrend-app.log.*"
fi
if [ "$WIFI_SUPPORT" == "true" ];then
    wpaSupplicantLog="wpa_supplicant.log"
    wpaSupplicantLogsBackup="wpa_supplicant.log.*"
    dhcpWifiLog="dhcp-wifi.log"
    dhcpWifiLogsBackup="dhcp-wifi.log.*"
fi
if [ "$DEVICE_TYPE" ==  "XHC1" ];then

        streamsrvLog="stream_server_log.txt"
        streamsrvLogsBackup="stream_server_log.txt.*"

        stunnelHttpsLog="stunnel_https_log.txt"
        stunnelHttpsLogsBackup="stunnel_https_log.txt.*"

        upnpLog="upnp_log.txt"
        upnpLogsBackup="upnp_log.txt.*"

        upnpigdLog="upnpigd_log.txt"
        upnpigdLogsBackup="upnpigd_log.txt.*"

        cgiLog="cgi_log.txt"
        cgiLogsBackup="cgi_log.txt.*"

        systemLog="system_log.txt"
        systemLogsBackup="system_log.txt.*"

        eventLog="event_log.txt"
        eventLogsBackup="event_log.txt.*"

        xw3MonitorLog="oem_log.txt"
        xw3MonitorLogsBackup="oem_log.txt.*"

        sensorDLog="sensor_daemon_log.txt"
        sensorDLogsBackup="sensor_daemon_log.txt.*"

        webpaLog="webpa_log.txt"
        webpaLogsBackup="webpa_log.txt.*"
 
        userLog="user_log.txt"
        userLogsBackup="user_log.txt.*"
        
        webrtcStreamingLog="webrtc_streaming_log.txt"
        webrtcStreamingLogsBackup="webrtc_streaming_log.txt.*"
        
        cvrPollLog="cvrpoll_log.txt"
        cvrPollLogsBackup="cvrpoll_log.txt.*"
  
        watchDogLog="watchDog_log.txt"
        watchDogLogsBackup="watchDog_log.txt.*"

        xwSystemLog="xwSystemInfo.log"
        xwSystemLogsBackup="xwSystemInfo.log.*"

        thumbnailUploadLog="thumbnail_log.txt"
        thumbnailUploadBackupLog="thumbnail_log.txt.*"

        audioAnalyticsLog="xcvaa_log.txt"
        audioAnalyticsLogBackup="xcvaa_log.txt.*"

        metricsLog="dmesg_log.txt"
        metricsLogsBackup="dmesg_log.txt.*"

        wifiLog="wifi_log.txt"
        wifiLogsBackup="wifi_log.txt.*"

        rfcLog="rfcscript.log"
        rfcLogsBackup="rfcscript.log.*"

        xvisionLog="xvision_log.txt"
        xvisionLogsBackup="xvision_log.txt.*"

        evoLog="evo_log.txt"
        evoBackupLog="evo_log.txt.*"

        overlayLog="overlay_log.txt"
        overlayLogsBackup="overlay_log.txt.*"

	iavencoderLog="iav_encoder_log.txt"
	iavencoderLogsBackup="iav_encoder_log.txt.*"

        smartrcLog="smartrc_log.txt"
        smartrcLogsBackup="smartrc_log.txt.*"

        smartThumbnailLog="smart_thumbnail_log.txt"
        smartThumbnailLogBackup="smart_thumbnail_log.txt.*"

	compatiblexwLog="compatible_xw_log.txt"
	compatiblexwLogsBackup="compatible_xw_log.txt.*"

	ledmgrLog="ledmgr_log.txt"
	ledmgrLogsBackup="ledmgr_log.txt.*"

        xwconfigLog="xwconfig_log.txt"
        xwconfigLogsBackup="xwconfig_log.txt.*"

        xwconsoleLog="xwconsole_log.txt"
        xwconsoleLogsBackup="xwconsole_log.txt.*"

        wirelessdriverLog="wirelessdriver_log.txt"
        wirelessdriverLogsBackup="wirelessdriver_log.txt.*"
	prvnmgrLog="prvnmgr_log.txt"
	prvnmgrLogsBackup="prvnmgr_log.txt.*"

        batterymgrLog="battery_log.txt"
        batterymgrLogsBackup="battery_log.txt.*"

        gpiobuttonLog="gpio_push_button_log.txt"
        gpiobuttonLogsBackup="gpio_push_button_log.txt.*"

        xwrebootInfoLog="rebootInfo_log.txt"
        xwrebootInfoLogsBackup="rebootInfo_log.txt.*"

	thermalControlLog="thermal_control_log.txt"
	thermalControlLogsBackup="thermal_control_log.txt.*"

        libledgerLog="libledger.log"
        libledgerLogsBackup="libledger.log.*"
        
        xw3systeminfoLog="xw3_last_system_info.log"
        xw3systeminfoLogsBackup="xw3_last_system_info.log.*"

        accessmanagerLog="accessmanager.log"
        accessmanagerLogsBackup="accessmanager.log.*"
fi

if [ "$HDD_ENABLED" = "false" ]; then
    sysLogBAK1="bak1_messages.txt"
    sysLogBAK2="bak2_messages.txt"
    sysLogBAK3="bak3_messages.txt"
    logBAK1="bak1_*"
    logBAK2="bak2_*"
    logBAK3="bak3_*"
fi

moveFile()
{        
     if [[ -f $1 ]]; then mv $1 $2; fi
}
 
moveFiles()
{
     currentDir=`pwd`
     cd $2
     
     for f in `ls $3 2>/dev/null`
     do
       $1 $f $4
     done
     
     cd $currentDir
}

backup()
{
    source=$1
    destn=$2
    operation=$3
    if [ "$DEVICE_TYPE" != "mediaclient" ]; then
          if [ -f $source$riLog ] ; then $operation $source$riLog $destn; fi
          if [ -f $mpeosRebootLog ] ; then
               if [ "$BUILD_TYPE" = "dev" ]; then
                    cp $mpeosRebootLog $destn
                    mv $recorderLog $destn
               else
                    mv $recorderLog $destn
                    $operation $mpeosRebootLog $destn
               fi
          fi
    fi
    if [ -f $source$emmcDebugLog ];then $operation $source$emmcDebugLog $destn; fi
    if [ -f $source$emmcHealthLog ];then $operation $source$emmcHealthLog $destn; fi
    if [ -f $source$xreLog ] ; then $operation $source$xreLog $destn; fi
    if [ -f $source$ttsLog ] ; then $operation $source$ttsLog $destn; fi
    if [ -f $source$cecLog ] ; then $operation $source$cecLog $destn; fi
    if [ "$WHITEBOX_ENABLED" == "true" ]; then
          if [ -f $source$wbLog ] ; then $operation $source$wbLog $destn; fi
    fi
    if [ -f $source$sysLog ] ; then $operation $source$sysLog $destn; fi
    if [ -f $source$ntpLog ] ; then $operation $source$ntpLog $destn; fi
    if [ -f $source/$uiLog ] ; then $operation $source/$uiLog $destn; fi
    if [ -f $source/$storagemgrLog ] ; then $operation $source/$storagemgrLog $destn; fi
    if [ -f $source/$speedtestLog ] ; then $operation $source/$speedtestLog $destn; fi
    if [ -f $source/$rf4ceLog ] ; then $operation $source/$rf4ceLog $destn; fi
    if [ -f $source/$ctrlmLog ] ; then $operation $source/$ctrlmLog $destn; fi
    if [ -f $source/$applicationsLog ] ; then $operation $source/$applicationsLog $destn; fi
    if [ -f $source/$systemLog ] ; then $operation $source/$systemLog $destn; fi
    if [ -f $source/$bootUpLog ] ; then $operation $source/$bootUpLog $destn; fi
    if [ -f $source/$startupDmesgLog ] ; then $operation $source/$startupDmesgLog $destn; fi
    if [ -f $source/$diskCleanupLog ] ; then $operation $source/$diskCleanupLog $destn; fi
    if [ -f $source/$diskCleanupInfoLog ] ; then $operation $source/$diskCleanupInfoLog $destn; fi
    if [ -f $source$sysDmesgLog ] ; then $operation $source$sysDmesgLog $destn; fi
    if [ -f $source$coreDumpLog ] ; then $operation $source$coreDumpLog $destn; fi
    if [ -f $source$bluetoothLog ] ; then $operation $source$bluetoothLog $destn; fi
    if [ -f $source$bluezLog ] ; then $operation $source$bluezLog $destn; fi
    if [ -f $source$mountLog ] ; then $operation $source$mountLog $destn; fi
    if [ -f $source$easPcapFile ] ; then $operation $source$easPcapFile $destn; fi
    if [ -f $source$mocaPcapFile ] ; then $operation $source$mocaPcapFile $destn; fi
    if [ -f $source$adobeCleanupLog ] ; then $operation $source$adobeCleanupLog $destn; fi
    if [ -f $source/$appsRdmLog ] ; then $operation $source/$appsRdmLog $destn; fi
    if [ -f $source/$gstreamerLog ] ; then $operation $source/$gstreamerLog $destn; fi
    if [ -f $source/$pathFailLog ] ; then $operation $source/$pathFailLog $destn; fi
    if [ -f $source/$hwselfresultsLog ] ; then $operation $source/$hwselfresultsLog $destn; fi
    if [ -f $source/$lxyLog ] ; then $operation $source/$lxyLog $destn; fi
    if [ -f $source/$webpavideoLog ] ; then $operation $source/$webpavideoLog $destn; fi
    if [ -f $source/$cronjobLog ] ; then $operation $source/$cronjobLog $destn; fi
    if [ -f $source/$logrotateLog ] ; then $operation $source/$logrotateLog $destn; fi
    if [ -f $source/$systimemgrLog ] ; then $operation $source/$systimemgrLog $destn; fi
    if [ "$CONTAINER_SUPPORT" == "true" ];then
        if [ -f $source$xreLxcLog ] ; then $operation $source$xreLxcLog $destn; fi
        if [ -f $source/$xreLxcApplicationsLog ] ; then $operation $source/$xreLxcApplicationsLog $destn; fi
    fi
    if [ "$DOBBY_ENABLED" == "true" ];then
        if [ -f $source$dobbyLog ] ; then $operation $source$dobbyLog $destn; fi
    fi
    if [ "$SOC" = "BRCM" ];then
         if [ -f $source$nxSvrLog ] ; then $operation $source$nxSvrLog $destn; fi
         if [ "$PROC_STATUS_LOG_SUPPORT" = "true" ];then
             if [ -f $source$procStatusLog ] ; then $operation $source$procStatusLog $destn; fi
         fi
    fi
    if [ "$SOC" = "AMLOGIC" ];then
	if [ -f $source$AudioServerLog ] ; then $operation $source$AudioServerLog $destn; fi
	if [ -f $source$TvServerLog ] ; then $operation $source$TvServerLog $destn; fi
	if [ -f $source/$PqserverLog ] ; then $operation $source/$PqserverLog $destn; fi
        if [ -f $source/$Dolbyms12Log ] ; then $operation $source/$Dolbyms12Log $destn; fi
    fi

    if [ "$SOC" = "RTK" ];then
        if [ -f $source$realtekDmesgKernelLog ] ; then $operation $source$realtekDmesgKernelLog $destn; fi
        if [ -f $source$realtekConsoleKernelLog ] ; then $operation $source$realtekConsoleKernelLog $destn; fi 
        if [ -f $source$realtekServiceLog ] ; then $operation $source$realtekServiceLog $destn; fi
        if [ -f $source$realtekFWLog ] ; then $operation $source$realtekFWLog $destn; fi
        if [ -f $source$realtekAFWLicenseCheckLog ] ; then $operation $source$realtekAFWLicenseCheckLog $destn; fi
    fi

    if [ "$MEDIARITE" == "true" ];then
	if [ -f $source$MediaRiteLog ] ; then $operation $source$MediaRiteLog $destn; fi
    fi
    if [ "$SKY_EPG_SUPPORT" == "true" ] || [ "$SKY_SERVICE_LOGGING" == "true" ]; then
         if [ -f $source$skyMessagesLog ] ; then $operation $source$skyMessagesLog $destn; fi
    fi
	if [ -f $source$subttxrendappLog ] ; then $operation $source$subttxrendappLog $destn; fi
}

crashLogsBackup()
{
    opern=$1
    src=$2
    destn=$3

    moveFiles $opern $src receiver.log_* $destn
    moveFiles $opern $src ocapri_log.txt_* $destn
    moveFiles $opern $src messages.txt_* $destn
    moveFiles $opern $src app_status_backup.log_* $destn
    if [ "$SKY_EPG_SUPPORT" == "true" ] || [ "$SKY_SERVICE_LOGGING" == "true" ]; then
       moveFiles $opern $src sky-messages.log_* $destn
    fi
}

backupAppBackupLogFiles()
{
     opern=$1
     source=$2
     destn=$3
    
     if [ "$DEVICE_TYPE" != "mediaclient" ]; then
         moveFiles $opern $source $riLogsBackup $destn
	 moveFiles $opern $source $ecmLogsBackup $destn
         moveFiles $opern $source $pumaLogsBackup $destn
         moveFiles $opern $source $snmpdLogsBackup $destn
         moveFiles $opern $source $upstreamStatsLogsBackup $destn
         moveFiles $opern $source $dibblerLogsBackup $destn
         moveFiles $opern $source $cpuprocanalyzerLogsBackup $destn
         moveFiles $opern $source $namedLogsBackup $destn
         moveFiles $opern $source $dnsqueryLogsBackup $destn
     else
         moveFiles $opern $source $wifiTelemetryLogBackup $destn
         moveFiles $opern $source $tr69AgentLogBackup $destn
         moveFiles $opern $source $tr69AgentHttpLogsBackup $destn
         moveFiles $opern $source $tr69AgentSoapLogsBackup $destn
         moveFiles $opern $source $parodusLogsBackup $destn
         moveFiles $opern $source $ConnectionStatusLogsBackup $destn
         moveFiles $opern $source $cpuprocanalyzerLogsBackup $destn
         moveFiles $opern $source $namedLogsBackup $destn
         moveFiles $opern $source $dnsqueryLogsBackup $destn
     fi
     if [ "$WIFI_SUPPORT" == "true" ];then
         moveFiles $opern $source $wpaSupplicantLogsBackup $destn
         moveFiles $opern $source $dhcpWifiLogsBackup $destn
     fi
     if [ "$DEVICE_TYPE" ==  "XHC1" ];then
        moveFiles $opern $source $streamsrvLogsBackup $destn
        moveFiles $opern $source $stunnelHttpsLogsBackup $destn
        moveFiles $opern $source $upnpLogsBackup $destn
        moveFiles $opern $source $upnpigdLogsBackup $destn
        moveFiles $opern $source $cgiLogsBackup $destn
        moveFiles $opern $source $systemLogsBackup $destn
        moveFiles $opern $source $eventLogsBackup $destn
        moveFiles $opern $source $xw3MonitorLogsBackup $destn
        moveFiles $opern $source $sensorDLogsBackup $destn
        moveFiles $opern $source $webpaLogsBackup $destn
        moveFiles $opern $source $userLogsBackup $destn
        moveFiles $opern $source $webrtcStreamingLogsBackup $destn
	moveFiles $opern $source $xvisionLogsBackup $destn
        moveFiles $opern $source $cvrPollLogsBackup $destn
        moveFiles $opern $source $watchDogLogsBackup $destn
        moveFiles $opern $source $xwSystemLogsBackup $destn
        moveFiles $opern $source $audioAnalyticsLogBackup $destn
        moveFiles $opern $source $ivaDaemonLogsBackup $destn
        moveFiles $opern $source $thumbnailUploadBackupLog $destn
        moveFiles $opern $source $metricsLogsBackup $destn
        moveFiles $opern $source $wifiLogsBackup $destn
        moveFiles $opern $source $dcmLogsBackup $destn
        moveFiles $opern $source $dnsmasqLogsBackup $destn
        moveFiles $opern $source $netsrvLogsBackup $destn
        moveFiles $opern $source $diskCleanupLogsBackup $destn
        moveFiles $opern $source $applicationsLogsBackup $destn
        moveFiles $opern $source $rfcLogsBackup $destn
        moveFiles $opern $source $sysLogsBackup $destn
        moveFiles $opern $source $startupDmesgLogsBackup $destn
        moveFiles $opern $source $sysDmesgLogsBackup $destn
        moveFiles $opern $source $evoBackupLog $destn
        moveFiles $opern $source $overlayLogsBackup $destn
        moveFiles $opern $source $iavencoderLogsBackup $destn
        moveFiles $opern $source $smartrcLogsBackup $destn
        moveFiles $opern $source $smartThumbnailLogBackup $destn
	moveFiles $opern $source $compatiblexwLogsBackup $destn
        moveFiles $opern $source $ledmgrLogsBackup $destn
	moveFiles $opern $source $xwconfigLogsBackup $destn
        moveFiles $opern $source $xwconsoleLogsBackup $destn
        moveFiles $opern $source $wirelessdriverLogsBackup $destn
	moveFiles $opern $source $prvnmgrLogsBackup $destn
        moveFiles $opern $source $batterymgrLogsBackup $destn
        moveFiles $opern $source $gpiobuttonLogsBackup $destn
	moveFiles $opern $source $thermalControlLogsBackup $destn
        moveFiles $opern $source $xwrebootInfoLogsBackup $destn
        moveFiles $opern $source $libledgerLogsBackup $destn
        moveFiles $opern $source $xw3systeminfoLogsBackup $destn
        moveFiles $opern $source $accessmanagerLogsBackup $destn
     else
     	moveFiles $opern $source $mocaStatusLogsBackup $destn
        moveFiles $opern $source $mocaDriverLogsBackup $destn
        moveFiles $opern $source $mocaServiceLogsBackup $destn
     	moveFiles $opern $source $runXreLogsBackup $destn
     	moveFiles $opern $source $xreLogsBackup $destn
     	moveFiles $opern $source $ttsLogsBackup $destn
     	moveFiles $opern $source $cecLogsBackup $destn
     	moveFiles $opern $source $sysLogsBackup $destn
     	moveFiles $opern $source $ntpLogsBackup $destn
     	moveFiles $opern $source $startupDmesgLogsBackup $destn
     	moveFiles $opern $source $gpInitLogsBackup $destn
     	moveFiles $opern $source $appStatusLogsBackup $destn
     	moveFiles $opern $source $dmesgLogsBackup $destn
     	moveFiles $opern $source $xDiscoveryLogsBackup $destn
     	moveFiles $opern $source $xDiscoveryListLogsBackup $destn
     	moveFiles $opern $source $uiLogsBackup $destn
     	moveFiles $opern $source $storagemgrLogsBackup $destn
     	moveFiles $opern $source $speedtestLogsBackup $destn
     	moveFiles $opern $source $rf4ceLogsBackup $destn
     	moveFiles $opern $source $ctrlmLogsBackup $destn
     	moveFiles $opern $source $lighttpdErrorLogsBackup $destn
     	moveFiles $opern $source $lighttpdAccessLogsBackup $destn
     	moveFiles $opern $source $dcmLogsBackup $destn
        moveFiles $opern $source $dnsmasqLogsBackup $destn
     	moveFiles $opern $source $greenpeakLogsBackup $destn
     	moveFiles $opern $source $trmLogsBackup $destn
     	moveFiles $opern $source $trmMgrLogsBackup $destn
     	moveFiles $opern $source $rmfLogsBackup $destn
     	moveFiles $opern $source $podLogsBackup $destn
     	moveFiles $opern $source $vodLogsBackup $destn
     	moveFiles $opern $source $fdsLogsBackup $destn
     	moveFiles $opern $source $vlThreadLogsBackup $destn
     	moveFiles $opern $source $xDeviceLogsBackup $destn
     	moveFiles $opern $source $coreDumpLogsBackup $destn
     	moveFiles $opern $source $applicationsLogsBackup $destn
     	moveFiles $opern $source $socProvisionLogsBackup $destn
        moveFiles $opern $source $socProvisionCryptoLogsBackup $destn
     	moveFiles $opern $source $topOsalLogsBackup $destn
     	moveFiles $opern $source $decoderStatusLogsBackup $destn
     	moveFiles $opern $source $mfrLogsBackup $destn
     	moveFiles $opern $source $mfrLogsRdkBackup $destn
     	moveFiles $opern $source $sysDmesgLogsBackup $destn
     	moveFiles $opern $source $resetLogsBackup $destn
     	moveFiles $opern $source $gpLogsBackup $destn
     	moveFiles $opern $source $psLogsBackup $destn
     	moveFiles $opern $source $topLogsBackup $destn
     	moveFiles $opern $source $netsrvLogsBackup $destn
     	moveFiles $opern $source $diskCleanupLogsBackup $destn
        moveFiles $opern $source $fogLogsBackup $destn 
     	moveFiles $opern $source $hddStatusLogsBackup $destn
     	moveFiles $opern $source $xiRecoveryLogsBackup $destn
     	moveFiles $opern $source $bluetoothLogBackup $destn
     	moveFiles $opern $source $bluezLogBackup $destn
        moveFiles $opern $source $mountLogBackup $destn
     	moveFiles $opern $source $easPcapFile $destn
     	moveFiles $opern $source $mocaPcapFile $destn
        moveFiles $opern $source $rbiDaemonLogsBackup $destn
        moveFiles $opern $source $rfcLogsBackup $destn
        moveFiles $opern $source $tlsLogsBackup $destn
        moveFiles $opern $source $pingTelemetryLogsBackup $destn
        moveFiles $opern $source $nlmonLogsBackup $destn
        moveFiles $opern $source $hwselfLogsBackup $destn
        moveFiles $opern $source $wpeframeworkLogsBackup $destn
        moveFiles $opern $source $residentAppLogsBackup $destn
        moveFiles $opern $source $servicenumberLogsBackup $destn
    	moveFiles $opern $source $rebootreasonLog $destn
     	moveFiles $opern $source $rebootreasonLogsBackup $destn
    	moveFiles $opern $source $dropbearLog $destn
     	moveFiles $opern $source $dropbearLogsBackup $destn
        moveFiles $opern $source $appmanagerLogsBackup $destn
        moveFiles $opern $source $xdialLogsBackup $destn
        moveFiles $opern $source $btrLeAppMgrLogsBackup $destn
        moveFiles $opern $source $dibblerclientLogsBackup $destn
        moveFiles $opern $source $ecfsLogsBackup $destn
        moveFiles $opern $source $iptablesLogsBackup $destn
        moveFiles $opern $source $perfmonstatusLogsBackup $destn
        moveFiles $opern $source $rdkmilestonesLogsBackup $destn
        moveFiles $opern $source $stunnelLogsBackup $destn
        moveFiles $opern $source $tr69HostIfLogsBackup $destn
        moveFiles $opern $source $cgrpmemoryLogsBackup $destn
        moveFiles $opern $source $cgrmemorytestLogsBackup $destn
        moveFiles $opern $source $hdcpLogsBackup $destn
        moveFiles $opern $source $threadLogsBackup $destn
        moveFiles $opern $source $dnsmasqLogsBackup $destn
        moveFiles $opern $source $bootUpLogsBackup $destn
        moveFiles $opern $source $LastUrlLogsBackup $destn
        moveFiles $opern $source $CrashedUrlLogsBackup $destn
        moveFiles $opern $source $nslookupLogsBackup $destn
        moveFiles $opern $source $tracerouteLogsBackup $destn
        moveFiles $opern $source $traceroute6LogsBackup $destn
        moveFiles $opern $source $pathFailLogsBackup $destn
        moveFiles $opern $source $rtroutedLogsBackup $destn
        moveFiles $opern $source $hwselfresultsLogsBackup $destn
        moveFiles $opern $source $lxyLogsBackup $destn
        moveFiles $opern $source $webpavideoLogsBackup $destn
        moveFiles $opern $source $cronjobLogsBackup $destn
        moveFiles $opern $source $logrotateLogsBackup $destn
        moveFiles $opern $source $systimemgrLogsBackup $destn
	moveFiles $opern $source $factoryCommsLogsBackup $destn
     fi

     if [ "$CONTAINER_SUPPORT" == "true" ];then
         moveFiles $opern $source $xreLxcLogsBackup $destn
         moveFiles $opern $source $xreLxcApplicationsLogsBackup $destn
     fi
     if [ "$DOBBY_ENABLED" == "true" ];then
         moveFiles $opern $source $dobbyLogsBackup $destn
     fi
     moveFiles $opern $source $systemLogsBackup $destn
     if [ "$SOC" = "BRCM" ];then
          moveFiles $opern $source $nxSvrLogsBackup $destn
          if [ "$PROC_STATUS_LOG_SUPPORT" = "true" ];then
              moveFiles $opern $source $procStatusLogsBackup $destn
          fi
     fi
     if [ "$SOC" = "AMLOGIC" ];then
	moveFiles $opern $source $AudioServerLogsBackup $destn
	moveFiles $opern $source $TvServerLogsBackup $destn
	moveFiles $opern $source $PqserverLogsBackup $destn
        moveFiles $opern $source $Dolbyms12LogsBackup $destn
     fi
     if [ "$SOC" = "RTK" ];then
        moveFiles $opern $source $realtekDmesgKernelLogBackup $destn
        moveFiles $opern $source $realtekConsoleKernelLogBackup $destn
        moveFiles $opern $source $realtekServiceLogBackup $destn
        moveFiles $opern $source $realtekFWLogBackup $destn
        moveFiles $opern $source $realtekAFWLicenseCheckLogBackup $destn
     fi

     if [ "$MEDIARITE" == "true" ];then
	moveFiles $opern $source $MediaRiteLogsBackup $destn
     fi
     # backup older cycle logs
     if [ "$MEMORY_LIMITATION_FLAG" = "true" ]; then
          moveFiles $opern $source $logBAK1 $destn
          moveFiles $opern $source $logBAK2 $destn
          moveFiles $opern $source $logBAK3 $destn
     fi

     if [ "$SKY_EPG_SUPPORT" = "true" ] || [ "$SKY_SERVICE_LOGGING" == "true" ]; then
        moveFiles $opern $source $skyMessagesLogBackup $destn
     fi
    moveFiles $opern $source $subttxrendappLogBackup $destn

}

backupSystemLogFiles()
{
     operation=$1
     source=$2
     destn=$3
     # generic Logs
     if [ -f $source/$systemLog ] ; then $operation $source/$systemLog $destn; fi
     if [ -f $source/$resetLog ] ; then $operation $source/$resetLog $destn; fi
     if [ -f $source/$backUpDumpLog ] ; then $operation $source/$backUpDumpLog $destn; fi
     if [ -f $source/$bootUpLog ] ; then $operation $source/$bootUpLog $destn; fi
     if [ -f $source/$applicationsLog ] ; then $operation $source/$applicationsLog $destn; fi
     if [ -f $source/$runXreLog ] ; then $operation $source/$runXreLog $destn; fi
     if [ -f $source/$xreLog ] ; then $operation $source/$xreLog $destn; fi
     if [ -f $source/$ttsLog ] ; then $operation $source/$ttsLog $destn; fi
     if [ -f $source/$cecLog ] ; then $operation $source/$cecLog $destn; fi
     if [ -f $source/$gpInitLog ] ; then $operation $source/$gpInitLog $destn; fi
     if [ -f $source/$hdmiLog ] ; then $operation $source/$hdmiLog $destn; fi
     if [ -f $source/$uiLog ] ; then $operation $source/$uiLog $destn; fi
     if [ -f $source/$storagemgrLog ] ; then $operation $source/$storagemgrLog $destn; fi
     if [ -f $source/$speedtestLog ] ; then $operation $source/$speedtestLog $destn; fi
     if [ -f $source/$rf4ceLog ] ; then $operation $source/$rf4ceLog $destn; fi
     if [ -f $source/$ctrlmLog ] ; then $operation $source/$ctrlmLog $destn; fi
     if [ -f $source/$ipdnlLog ] ; then $operation $source/$ipdnlLog $destn; fi

     if [ -f $source/$fdsLog ] ; then $operation $source/$fdsLog $destn; fi
     if [ -f $source/$dmesgLog ] ; then $operation $source/$dmesgLog $destn; fi
     if [ -f $source/$appStatusLog ] ; then $operation $source/$appStatusLog $destn; fi
     if [ -f $source/$gpLog ]; then $operation $source/$gpLog $destn; fi
     if [ -f $source/$sysLog ] ; then $operation $source/$sysLog $destn; fi
     if [ -f $source/$ntpLog ] ; then $operation $source/$ntpLog $destn; fi
     if [ "$WHITEBOX_ENABLED" == "true" ]; then
           if [ -f $source/$wbLog ] ; then $operation $source/$wbLog $destn; fi
     fi
     if [ -f $source/$ueiLog ] ; then $operation $source/$ueiLog $destn; fi
     if [ -f $source/$receiverMON ] ; then $operation $source/$receiverMON $destn; fi
     if [ -f $source/$swUpdateLog ] ; then $operation $source/$swUpdateLog $destn; fi
     if [ -f $source/$topLog ] ; then $operation $source/$topLog $destn; fi
     if [ -f $source/$fusionDaleLog ] ; then $operation $source/$fusionDaleLog $destn; fi

     if [ -f $source/$mfrLog ] ; then $operation $source/$mfrLog $destn; fi
     if [ -f $source/$mocaLog ] ; then $operation $source/$mocaLog $destn; fi
     if [ -f $source/$rebootLog ] ; then $operation $source/$rebootLog $destn; fi
     if [ -f $source/$rebootInfoLog ] ; then $operation $source/$rebootInfoLog $destn; fi
     if [ -f $source/$xDiscoveryLog ] ; then $operation $source/$xDiscoveryLog $destn; fi
     if [ -f $source/$xDiscoveryListLog ] ; then $operation $source/$xDiscoveryListLog $destn; fi

     if [ -f $source/$socProvisionLog ] ; then $operation $source/$socProvisionLog $destn; fi
     if [ -f $source/$socProvisionCryptoLog ] ; then $operation $source/$socProvisionCryptoLog $destn; fi
     if [ -f $source/$lighttpdErrorLog ] ; then $operation $source/$lighttpdErrorLog $destn; fi
     if [ -f $source/$lighttpdAccessLog ] ; then $operation $source/$lighttpdAccessLog $destn; fi
     if [ -f $source/$dcmLog ] ; then $operation $source/$dcmLog $destn; fi
     if [ -f $source/$dnsmasqLog ] ; then $operation $source/$dnsmasqLog $destn; fi
     if [ -f $source/$coreDumpLog ] ; then $operation $source/$coreDumpLog $destn; fi
     if [ -f $source/$bluetoothLog ] ; then $operation $source/$bluetoothLog $destn; fi
     if [ -f $source/$bluezLog ] ; then $operation $source/$bluezLog $destn; fi
     if [ -f $source/$mountLog ] ; then $operation $source/$mountLog $destn; fi
     if [ -f $source/$appsRdmLog ] ; then $operation $source/$appsRdmLog $destn; fi
     if [ -f $source/$gstreamerLog ] ; then $operation $source/$gstreamerLog $destn; fi
     if [ -f $source/$rbiDaemonLog ] ; then $operation $source/$rbiDaemonLog $destn; fi
     if [ -f $source/$rfcLog ] ; then $operation $source/$rfcLog $destn; fi
     if [ -f $source/$tlsLog ] ; then $operation $source/$tlsLog $destn; fi
     if [ -f $source/$pingTelemetryLog ] ; then $operation $source/$pingTelemetryLog $destn; fi
     if [ -f $source/$deviceDetailsLog ] ; then $operation $source/$deviceDetailsLog $destn; fi
     if [ -f $source/$nlmonLog ] ; then $operation $source/$nlmonLog $destn; fi
     if [ -f $source/$hwselfLog ] ; then $operation $source/$hwselfLog $destn; fi
     if [ -f $source/$wpeframeworkLog ] ; then $operation $source/$wpeframeworkLog $destn; fi
     if [ -f $source/$residentAppLog ] ; then $operation $source/$residentAppLog $destn; fi
     if [ -f $source/$servicenumberLog ] ; then $operation $source/$servicenumberLog $destn; fi
     if [ -f $source/$appmanagerLog ] ; then $operation $source/$appmanagerLog $destn; fi
     if [ -f $source/$xdialLog ] ; then $operation $source/$xdialLog $destn; fi
     if [ -f $source/$btrLeAppMgrLog ] ; then $operation $source/$btrLeAppMgrLog $destn; fi
     if [ -f $source/$dibblerclientLog ] ; then $operation $source/$dibblerclientLog $destn; fi
     if [ -f $source/$ecfsLog ] ; then $operation $source/$ecfsLog $destn; fi
     if [ -f $source/$iptablesLog ] ; then $operation $source/$iptablesLog $destn; fi
     if [ -f $source/$perfmonstatusLog ] ; then $operation $source/$perfmonstatusLog $destn; fi
     if [ -f $source/$rdkmilestonesLog ] ; then $operation $source/$rdkmilestonesLog $destn; fi
     if [ -f $source/$stunnelLog ] ; then $operation $source/$stunnelLog $destn; fi
     if [ -f $source/$tr69HostIfLog ] ; then $operation $source/$tr69HostIfLog $destn; fi
     if [ -f $source/$cgrpmemoryLog ] ; then $operation $source/$cgrpmemoryLog $destn; fi
     if [ -f $source/$cgrmemorytestLog ] ; then $operation $source/$cgrmemorytestLog $destn; fi
     if [ -f $source/$hdcpLog ] ; then $operation $source/$hdcpLog $destn; fi
     if [ -f $source/$threadLog ] ; then $operation $source/$threadLog $destn; fi
     if [ -f $source/$dnsmasqLog ] ; then $operation $source/$dnsmasqLog $destn; fi
     if [ -f $source/$LastUrlLog ] ; then $operation $source/$LastUrlLog $destn; fi
     if [ -f $source/$CrashedUrlLog ] ; then $operation $source/$CrashedUrlLog $destn; fi
     if [ -f $source/$nslookupLog ] ; then $operation $source/$nslookupLog $destn; fi
     if [ -f $source/$tracerouteLog ] ; then $operation $source/$tracerouteLog $destn; fi
     if [ -f $source/$traceroute6Log ] ; then $operation $source/$traceroute6Log $destn; fi
     if [ -f $source/$pathFailLog ] ; then $operation $source/$pathFailLog $destn; fi
     if [ -f $source/$rtroutedLog ] ; then $operation $source/$rtroutedLog $destn; fi
     if [ -f $source/$hwselfresultsLog ] ; then $operation $source/$hwselfresultsLog $destn; fi
     if [ -f $source/$lxyLog ] ; then $operation $source/$lxyLog $destn; fi
     if [ -f $source/$webpavideoLog ] ; then $operation $source/$webpavideoLog $destn; fi
     if [ -f $source/$cronjobLog ] ; then $operation $source/$cronjobLog $destn; fi
     if [ -f $source/$logrotateLog ] ; then $operation $source/$logrotateLog $destn; fi
     if [ -f $source/$systimemgrLog ] ; then $operation $source/$systimemgrLog $destn; fi
     if [ -f $source/$factoryCommsLog ] ; then $operation $source/$factoryCommsLog $destn; fi
     if [ "$CONTAINER_SUPPORT" == "true" ];then
         if [ -f $source/$xreLxcApplicationsLog ] ; then $operation $source/$xreLxcApplicationsLog $destn; fi
         if [ -f $source/$xreLxcLog ] ; then $operation $source/$xreLxcLog $destn; fi
     fi
     if [ "$DOBBY_ENABLED" == "true" ];then
         if [ -f $source/$dobbyLog ] ; then $operation $source/$dobbyLog $destn; fi
     fi
     #Adding a work around to create core_log.txt whith restricted user privilege
     #if linux multi user is enabled
     if [ "$ENABLE_MULTI_USER" == "true" ] && [ ! -f /etc/os-release ] ; then
        if [ "$BUILD_TYPE" == "prod" ] ; then
            touch $source/$coreDumpLog
            chown restricteduser:restrictedgroup $source/$coreDumpLog
        else
            if [ ! -f /opt/disable_chrootXREJail ]; then
                touch $source/$coreDumpLog
                chown restricteduser:restrictedgroup $source/$coreDumpLog
            fi
        fi
     fi
     #End of work around related to core_log.txt for Linux multi user support
     if [ -f $source/$trmLog ] ; then $operation $source/$trmLog $destn; fi
     if [ -f $source/$trmMgrLog ] ; then $operation $source/$trmMgrLog $destn; fi
     if [ -f $source/$vlThreadLog ] ; then $operation $source/$vlThreadLog $destn; fi
     if [ -f $source/$greenpeakLog ]; then $operation $source/$greenpeakLog $destn; fi
     if [ -f $source/$startupDmesgLog ] ; then $operation $source/$startupDmesgLog $destn; fi
     if [ -f $source/$coreLog ] ; then $operation $source/$coreLog $destn; fi
     if [ -f $source/$xDeviceLog ] ; then $operation $source/$xDeviceLog $destn; fi
     if [ -f $source/$rmfLog ] ; then $operation $source/$rmfLog $destn; fi
     if [ "$DEVICE_TYPE" != "mediaclient" ]; then
          if [ -f $source/$podLog ] ; then $operation $source/$podLog $destn; fi
          if [ -f $source/$vodLog ] ; then $operation $source/$vodLog $destn; fi
          if [ -f $source/$diskEventsLog ] ; then $operation $source/$diskEventsLog $destn; fi
          if [ -f $source/$diskInfoLog ] ; then $operation $source/$diskInfoLog $destn; fi
          if [ -f $source/$ablReasonLog ] ; then $operation $source/$ablReasonLog $destn; fi
          if [ -f $source/$mpeosmainMON ] ; then $operation $source/$mpeosmainMON $destn; fi
          if [ -f $source/$ecmLog ] ; then $operation $source/$ecmLog $destn; fi
          if [ -f $source/$pumaLog ] ; then $operation $source/$pumaLog $destn; fi
          if [ -f $source/$heapDmpLog ] ; then $operation $source/$heapDmpLog $destn; fi
          if [ -f $source/$cardStatusLog ] ; then $operation $source/$cardStatusLog $destn; fi
          if [ -f $source/$rfStatisticsLog ] ; then $operation $source/$rfStatisticsLog $destn; fi
          if [ -f $source/$riLog ] ; then $operation $source/$riLog $destn; fi
          if [ -f $source/$xfsdmesgLog ] ; then $operation $source/$xfsdmesgLog $destn; fi
          if [ -f $source/$parodusLog ] ; then $operation $source/$parodusLog $destn; fi
          if [ -f $source/$cpuprocanalyzerLog ] ; then $operation $source/$cpuprocanalyzerLog $destn; fi
          if [ -f $source/$namedLog ] ; then $operation $source/$namedLog $destn; fi
          if [ -f $source/$dnsqueryLog ] ; then $operation $source/$dnsqueryLog $destn; fi
          if [ -f $mpeosRebootLog ] ; then 
               if [ "$BUILD_TYPE" = "dev" ]; then
                    cp $mpeosRebootLog $destn
               else
                    $operation $mpeosRebootLog $destn
               fi
          fi
          if [ "$LIGHTSLEEP_ENABLE" = "true" ]; then
               if [ -f $source/$lightsleepLog ] ; then $operation $source/$lightsleepLog $destn; fi
          fi
          if [ -f $source/$snmpdLog ] ; then $operation $source/$snmpdLog $destn; fi
          if [ -f $source/$upstreamStatsLog ] ; then $operation $source/$upstreamStatsLog $destn; fi
          if [ -f $source/$dibblerLog ] ; then $operation $source/$dibblerLog $destn; fi
     else
	  if [ -f $source/$wifiTelemetryLog ] ; then $operation $source/$wifiTelemetryLog $destn; fi
	  if [ -f $source/$tr69Log ] ; then $operation $source/$tr69Log $destn; fi
	  if [ -f $source/$tr69AgentLog ] ; then $operation $source/$tr69AgentLog $destn; fi
	  if [ -f $source/$tr69DownloadLog ] ; then $operation $source/$tr69DownloadLog $destn; fi
	  if [ -f $source/$gatewayLog ] ; then $operation $source/$gatewayLog $destn; fi
	  if [ -f $source/$ipSetupLog ] ; then $operation $source/$ipSetupLog $destn; fi
	  if [ -f $source/$tr69AgentHttpLog ] ; then $operation $source/$tr69AgentHttpLog $destn; fi
	  if [ -f $source/$tr69AgentSoapLog ] ; then $operation $source/$tr69AgentSoapLog $destn; fi
      if [ -f $source/$parodusLog ] ; then $operation $source/$parodusLog $destn; fi
      if [ -f $source/$cpuprocanalyzerLog ] ; then $operation $source/$cpuprocanalyzerLog $destn; fi
      if [ -f $source/$ConnectionStatusLog ] ; then $operation $source/$ConnectionStatusLog $destn; fi
      if [ -f $source/$namedLog ] ; then $operation $source/$namedLog $destn; fi
      if [ -f $source/$dnsqueryLog ] ; then $operation $source/$dnsqueryLog $destn; fi
     fi
     # backup version.txt
     if [ -f $source/$version ] ; then 
	     $operation $source/$version $destn
     else
	     cp /$version $destn
     fi
     # backup older cycle logs
     if [ -f $source/$rstreamFdLog ] ; then $operation $source/$rstreamFdLog $destn; fi
     if [ -f $source/$authServiceLog ] ; then $operation $source/$authServiceLog $destn; fi
     if [ -f $source/$cardProvisionCheckLog ] ; then $operation $source/$cardProvisionCheckLog $destn; fi
     if [ -f $source/$diskCleanupLog ] ; then $operation $source/$diskCleanupLog $destn; fi
     if [ -f $source/$diskCleanupInfoLog ] ; then $operation $source/$diskCleanupInfoLog $destn; fi
     if [ -f $recorderLog ]; then mv $recorderLog $destn; fi
     if [ -f $source/$topOsalLog ] ; then $operation $source/$topOsalLog $destn; fi
     if [ -f $source/$mocaStatusLog ] ; then $operation $source/$mocaStatusLog $destn; fi
     if [ -f $source/$mocaDriverLog ] ; then $operation $source/$mocaDriverLog $destn; fi
     if [ -f $source/$mocaServiceLog ] ; then $operation $source/$mocaServiceLog $destn; fi
     if [ -f $source/$decoderStatusLog ] ; then $operation $source/$decoderStatusLog $destn; fi
     if [ -f $source/$mfrLogRdk ] ; then $operation $source/$mfrLogRdk $destn; fi
     if [ -f $source/$sysDmesgLog ] ; then $operation $source/$sysDmesgLog $destn; fi
     if [ -f $source/$xiRecoveryLog ] ; then $operation $source/$xiRecoveryLog $destn; fi
     if [ -f $source/$fogLog ] ; then $operation $source/$fogLog $destn; fi
     if [ -f $source/$hddStatusLog ] ; then $operation $source/$hddStatusLog $destn; fi
     if [ -f $source/$rebootReasonLog ] ; then $operation $source/$rebootReasonLog $destn; fi
     if [ -f $source/$rebootReasonLogsBackup ] ; then $operation $source/$rebootReasonLogsBackup $destn; fi
     if [ -f $source/$dropbearLog ] ; then $operation $source/$dropbearLog $destn; fi
     if [ -f $source/$dropbearLogsBackup ] ; then $operation $source/$dropbearLogsBackup $destn; fi

     if [ "$SOC" = "BRCM" ];then
         if [ -f $source/$nxSvrLog ] ; then $operation $source/$nxSvrLog $destn; fi
         if [ "$PROC_STATUS_LOG_SUPPORT" = "true" ];then
             if [ -f $source/$procStatusLog ] ; then $operation $source/$procStatusLog $destn; fi
         fi
     fi

     if [ "$SOC" = "AMLOGIC" ];then
	if [ -f $source$AudioServerLog ] ; then $operation $source$AudioServerLog $destn; fi
	if [ -f $source$TvServerLog ] ; then $operation $source$TvServerLog $destn; fi
     fi
     if [ "$SOC" = "RTK" ];then
        if [ -f $source$realtekDmesgKernelLog ] ; then $operation $source$realtekDmesgKernelLog $destn; fi
        if [ -f $source$realtekConsoleKernelLog ] ; then $operation $source$realtekConsoleKernelLog $destn; fi
        if [ -f $source$realtekServiceLog ] ; then $operation $source$realtekServiceLog $destn; fi
        if [ -f $source$realtekFWLog ] ; then $operation $source$realtekFWLog $destn; fi
        if [ -f $source$realtekAFWLicenseCheckLog ] ; then $operation $source$realtekAFWLicenseCheckLog $destn; fi
     fi


     if [ "$MEDIARITE" == "true" ];then
	if [ -f $source$MediaRiteLog ] ; then $operation $source$MediaRiteLog $destn; fi
     fi

     if [ -f $source/$netsrvLog ] ; then $operation $source/$netsrvLog $destn; fi
  
	  
    if [ "$DEVICE_TYPE" ==  "XHC1" ];then
        if [ -f $source/$streamsrvLog ] ; then $operation $source/$streamsrvLog $destn; fi
	if [ -f $source/$stunnelHttpsLog ] ; then $operation $source/$stunnelHttpsLog $destn; fi
	if [ -f $source/$upnpLog ] ; then $operation $source/$upnpLog $destn; fi
        if [ -f $source/$upnpigdLog ] ; then $operation $source/$upnpigdLog $destn; fi
	if [ -f $source/$cgiLog ] ; then $operation $source/$cgiLog $destn; fi
	if [ -f $source/$systemLog ] ; then $operation $source/$systemLog $destn; fi
	if [ -f $source/$eventLog ] ; then $operation $source/$eventLog $destn; fi
	if [ -f $source/$xw3MonitorLog ] ; then $operation $source/$xw3MonitorLog $destn; fi
        if [ -f $source/$sensorDLog ] ; then $operation $source/$sensorDLog $destn; fi
        if [ -f $source/$webpaLog ] ; then $operation $source/$webpaLog $destn; fi
        if [ -f $source/$userLog ] ; then $operation $source/$userLog $destn; fi
        if [ -f $source/$webrtcStreamingLog ] ; then $operation $source/$webrtcStreamingLog $destn; fi
        if [ -f $source/$xvisionLog ] ; then $operation $source/$xvisionLog $destn; fi
	if [ -f $source/$cvrPollLog ] ; then $operation $source/$cvrPollLog $destn; fi
	if [ -f $source/$watchDogLog ] ; then $operation $source/$watchDogLog $destn; fi
	if [ -f $source/$xwSystemLog ] ; then $operation $source/$xwSystemLog $destn; fi
        if [ -f $source/$audioAnalyticsLog ] ; then $operation $source/$audioAnalyticsLog $destn; fi
	if [ -f $source/$ivaDaemonLog ] ; then $operation $source/$ivaDaemonLog $destn; fi
	if [ -f $source/$thumbnailUploadLog ] ; then $operation $source/$thumbnailUploadLog $destn; fi
	if [ -f $source/$metricsLog ] ; then $operation $source/$metricsLog $destn; fi
	if [ -f $source/$wifiLog ] ; then $operation $source/$wifiLog $destn; fi
        if [ -f $source/$evoLog ] ; then $operation $source/$evoLog $destn; fi
	if [ -f $source/$overlayLog ] ; then $operation $source/$overlayLog $destn; fi
	if [ -f $source/$iavencoderLog ]; then $operation $source/$iavencoderLog $destn; fi
	if [ -f $source/$smartrcLog ]; then $operation $source/$smartrcLog $destn; fi
	if [ -f $source/$smartThumbnailLog ] ; then $operation $source/$smartThumbnailLog $destn; fi
	if [ -f $source/$compatiblexwLog ] ; then $operation $source/$compatiblexwLog $destn; fi
        if [ -f $source/$ledmgrLog ] ; then $operation $source/$ledmgrLog $destn; fi
	if [ -f $source/$xwconfigLog ] ; then $operation $source/$xwconfigLog $destn; fi
        if [ -f $source/$xwconsoleLog ] ; then $operation $source/$xwconsoleLog $destn; fi
        if [ -f $source/$wirelessdriverLog ] ; then $operation $source/$wirelessdriverLog $destn; fi
	if [ -f $source/$prvnmgrLog ] ; then $operation $source/$prvnmgrLog $destn; fi
	if [ -f $source/$batterymgrLog ] ; then $operation $source/$batterymgrLog $destn; fi
	if [ -f $source/$gpiobuttonLog ] ; then $operation $source/$gpiobuttonLog $destn; fi
	if [ -f $source/$thermalControlLog ] ; then $operation $source/$thermalControlLog $destn; fi
        if [ -f $source/$xwrebootInfoLog ] ; then $operation $source/$xwrebootInfoLog $destn; fi
        if [ -f $source/$libledgerLog ] ; then $operation $source/$libledgerLog $destn; fi
        if [ -f $source/$xw3systeminfoLog ] ; then $operation $source/$xw3systeminfoLog $destn; fi
        if [ -f $source/$accessmanagerLog ] ; then $operation $source/$accessmanagerLog $destn; fi
     fi
    if [ "$WIFI_SUPPORT" == "true" ];then
        if [ -f $source/$wpaSupplicantLog ] ; then $operation $source/$wpaSupplicantLog $destn; fi
        if [ -f $source/$dhcpWifiLog ] ; then $operation $source/$dhcpWifiLog $destn; fi
    fi
     if [ -f $source/$audiocapturemgrLogs ] ; then $operation $source/$audiocapturemgrLogs $destn; fi

     if [ -f $source/$adobeCleanupLog ] ; then $operation $source/$adobeCleanupLog $destn; fi
     if [ -f $source/$bluetoothLog ] ; then $operation $source/$bluetoothLog $destn; fi
     if [ -f $source/$bluezLog ] ; then $operation $source/$bluezLog $destn; fi
     if [ "$SKY_EPG_SUPPORT" == "true" ] || [ "$SKY_SERVICE_LOGGING" == "true" ]; then
        if [ -f $source/$skyMessagesLog ] ; then $operation $source/$skyMessagesLog $destn; fi
     fi
     if [ -f $source/$subttxrendappLog ] ; then $operation $source/$subttxrendappLog $destn; fi
}

logCleanup()
{
  echo "Done Log Backup"
}
