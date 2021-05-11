#!/bin/sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2016 RDK Management, LLC. All rights reserved.
# ============================================================================

. /etc/device.properties

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

# Define logfiles and flags
REBOOT_INFO_LOG_FILE="/opt/logs/rebootInfo.log"
KERNEL_LOG_FILE="/opt/logs/messages.txt"
DMESG_LOG_FILE="/opt/logs/startup_stdout_log.txt"
NXSERVER_LOG_FILE="/opt/logs/nxserver.log"
APPLICATION_LOG_FILE="/opt/logs/applications.log"
UIMGR_LOG_FILE="/opt/logs/PreviousLogs/uimgr_log.txt"
OCAPRI_LOG_FILE="/opt/logs/PreviousLogs/ocapri_log.txt"
ECM_CRASH_LOG_FILE="/opt/logs/PreviousLogs/messages-ecm.txt"
KERNEL_PANIC_SEARCH_STRING="PREVIOUS_KERNEL_OOPS_DUMP"
ECM_CRASH_SEARCH_STRING="\*\*\*\* CRASH \*\*\*\*"
MAX_REBOOT_STRING="Box has rebooted 10 times"
PR_STRING="PreviousRebootReason"
PREVIOUS_REBOOT_INFO_FILE="/opt/secure/reboot/previousreboot.info"
OLD_PREVIOUS_REBOOT_INFO_FILE="/opt/persistent/previousreboot.info"
REBOOT_INFO_DIR="/opt/secure/reboot"
REBOOT_INFO_FILE="/opt/secure/reboot/reboot.info"
KEYPRESS_INFO_FILE="/opt/secure/reboot/keypress.info"
PREVIOUS_KEYPRESS_INFO_FILE="/opt/secure/reboot/previouskeypress.info"
PREVIOUS_HARD_REBOOT_INFO_FILE="/opt/secure/reboot/hardpower.info"
OLD_PREVIOUS_HARD_REBOOT_INFO_FILE="/opt/persistent/hardpower.info"
STT_FLAG="/tmp/stt_received"
REBOOT_INFO_FLAG="/tmp/rebootInfo_Updated"
LOCK_DIR="/tmp/rebootInfo.lock"
RESET_LIST="/proc/device-tree/bolt/reset-list"

# Define reboot reasons for APP_TRIGGERED and OPS_TRIGGERED reasons
APP_TRIGGERED_REASONS=(Servicemanager systemservice_legacy WarehouseReset WarehouseService HrvInitWHReset HrvColdInitReset HtmlDiagnostics InstallTDK StartTDK TR69Agent)
OPS_TRIGGERED_REASONS=(ScheduledReboot RebootSTB.sh FactoryReset UpgradeReboot_firmwareDwnld.sh UpgradeReboot_restore XFS wait_for_pci0_ready websocketproxyinit NSC_IR_EventReboot host_interface_dma_bus_wait usbhotplug Receiver_MDVRSet Receiver_VidiPath_Enabled Receiver_Toggle_Optimus S04init_ticket Network-Service monitor.sh ecmIpMonitor.sh monitorMfrMgr.sh vlAPI_Caller_Upgrade ImageUpgrade_rmf_osal ImageUpgrade_mfr_api ImageUpgrade_updateNewImage.sh ImageUpgrade_userInitiatedFWDnld.sh ClearSICache tr69hostIfReset hostIf_utils hostifDeviceInfo HAL_SYS_Reboot UpgradeReboot_deviceInitiatedFWDnld.sh UpgradeReboot_ipdnl.sh PowerMgr_Powerreset PowerMgr_coldFactoryReset DeepSleepMgr PowerMgr_CustomerReset PowerMgr_PersonalityReset Power_Thermmgr PowerMgr_Plat HAL_CDL_notify_mgr_event vldsg_estb_poll_ecm_operational_state BcmIndicateEcmReset SASWatchDog BP3_Provisioning)
MAINTENANCE_TRIGGERED_REASONS=(AutoReboot.sh)


# Save the reboot info with all the fields
setPreviousRebootInfo()
{
    # Set Previous reboot info file with received reboot reason.
    timestamp=$1
    source=$2
    reason=$3
    custom=$4
    other=$5
    echo "{" > $PREVIOUS_REBOOT_INFO_FILE
    echo "\"timestamp\":\"$timestamp\"," >> $PREVIOUS_REBOOT_INFO_FILE
    echo "\"source\":\"$source\"," >> $PREVIOUS_REBOOT_INFO_FILE
    echo "\"reason\":\"$reason\"," >> $PREVIOUS_REBOOT_INFO_FILE
    echo "\"customReason\":\"$custom\"," >> $PREVIOUS_REBOOT_INFO_FILE
    echo "\"otherReason\":\"$other\"" >> $PREVIOUS_REBOOT_INFO_FILE
    echo "}" >> $PREVIOUS_REBOOT_INFO_FILE

    # Set Hard Power reset time with timestamp
    if [ "$reason" != "KERNEL_PANIC" ] || [ ! -f "$PREVIOUS_HARD_REBOOT_INFO_FILE" ];then
        echo "{" > $PREVIOUS_HARD_REBOOT_INFO_FILE
        echo "\"lastHardPowerReset\":\"$timestamp\"" >> $PREVIOUS_HARD_REBOOT_INFO_FILE
        echo "}" >> $PREVIOUS_HARD_REBOOT_INFO_FILE
        echo "Updated Hard Power Reboot Time stamp"
    fi

    echo "Updated Previous Reboot Reason information"
}

# Check for Firmware Failure
fwFailureCheck()
{
    fw_failure=0
    echo "Checking firmware failure cases (ECM Crash, Max Reboot etc)..."

    if [ "$DEVICE_TYPE" != "mediaclient" ]; then
        if  [ -f "$OCAPRI_LOG_FILE" ] && [[ $(grep "$MAX_REBOOT_STRING" $OCAPRI_LOG_FILE) ]]; then
            fw_failure=1
            rebootInitiatedBy="OcapRI"
            otherReason="Reboot due to STB reached maximum (10) reboots"
            t2CountNotify "SYST_ERR_10Times_reboot"
        fi

        if [ -f "$ECM_CRASH_LOG_FILE" ] && [[ $(grep "$ECM_CRASH_SEARCH_STRING" $ECM_CRASH_LOG_FILE) ]]; then
            fw_failure=1
            rebootInitiatedBy="EcmLogger"
            otherReason="Reboot due to ecm logger crash"
        fi
    else
        if  [ -f "$UIMGR_LOG_FILE" ] && [[ $(grep "$MAX_REBOOT_STRING" $UIMGR_LOG_FILE) ]]; then
            fw_failure=1
            rebootInitiatedBy="UiMgr"
            otherReason="Reboot due to STB reached maximum (10) reboots"
            t2CountNotify "SYST_ERR_10Times_reboot"
        fi
    fi

    return $fw_failure
}

# Check for OOPS DUMP string in Kernel panic scenarios
oopsDumpCheck()
{
    oops_dump=0

    # Ensure OOPS DUMP string presence for Kernel Panic in startup_stdout_log.txt.
    if [ -f "$DMESG_LOG_FILE" ] && [[ $(grep $KERNEL_PANIC_SEARCH_STRING $DMESG_LOG_FILE) ]];then
        oops_dump=1
        t2CountNotify "SYST_ERR_SrtupKCdump"
    fi

    # Ensure OOPS DUMP string presence for Kernel Panic in messages.txt
    if [ $oops_dump -eq 0 ];then
        if [ -f "$KERNEL_LOG_FILE" ] && [[ $(grep $KERNEL_PANIC_SEARCH_STRING $KERNEL_LOG_FILE) ]];then
            oops_dump=1
        fi
    fi

    # Ensure OOPS DUMP string presence for Kernel Panic in application.log
    if [ $oops_dump -eq 0 ];then
        if [ -f "$APPLICATION_LOG_FILE" ] && [[ $(grep $KERNEL_PANIC_SEARCH_STRING $APPLICATION_LOG_FILE) ]];then
            oops_dump=1
        fi
    fi
    
    return $oops_dump
}

#Read the HW Register value of  PreviousRebootReason and set details.
setRebootReason()
{
    rebootReason=$1

    case $rebootReason in
        SOFTWARE_MASTER_RESET)
            rebootInitiatedBy="SoftwareReboot"
            otherReason="Reboot due to user triggered reboot command"
            ;;
        WATCHDOG_TIMER_RESET)
            rebootInitiatedBy="WatchDog"
            otherReason="Reboot due to watch dog timer reset"
            ;;
        POWER_ON_RESET)
            rebootInitiatedBy="PowerOn"
            otherReason="Reboot due to unplug of power cable from the STB"
            ;;
        MAIN_CHIP_INPUT_RESET)
            rebootInitiatedBy="Main Chip"
            otherReason="Reboot due to chip's main reset input has been asserted"
            ;;
        MAIN_CHIP_RESET_INPUT)
            rebootInitiatedBy="Main Chip"
            otherReason="Reboot due to chip's main reset input has been asserted"
            ;;
        TAP_IN_SYSTEM_RESET)
            rebootInitiatedBy="Tap-In System"
            otherReason="Reboot due to the chip's TAP in-system reset has been asserted"
            ;;
        FRONT_PANEL_4SEC_RESET)
            rebootInitiatedBy="FrontPanel Button"
            otherReason="Reboot due to the front panel 4 second reset has been asserted"
            ;;
        S3_WAKEUP_RESET)
            rebootInitiatedBy="Standby Wakeup"
            otherReason="Reboot due to the chip woke up from deep standby"
            ;;
        SMARTCARD_INSERT_RESET)
            rebootInitiatedBy="SmartCard Insert"
            otherReason="Reboot due to the smartcard insert reset has occurred"
            ;;
        OVERTEMP_RESET)
            rebootInitiatedBy="OverTemperature"
            otherReason="Reboot due to chip temperature is above threshold (125*C)"
            ;;
        OVERVOLTAGE_1_RESET|OVERVOLTAGE_RESET)
            rebootInitiatedBy="OverVoltage"
            otherReason="Reboot due to chip voltage is above threshold"
            ;;
        PCIE_1_HOT_BOOT_RESET|PCIE_0_HOT_BOOT_RESET)
            rebootInitiatedBy="PCIE Boot"
            otherReason="Reboot due to PCIe hot boot reset has occurred"
            ;;
        UNDERVOLTAGE_1_RESET|UNDERVOLTAGE_0_RESET|UNDERVOLTAGE_RESET)
            rebootInitiatedBy="LowVoltage"
            otherReason="Reboot due to chip voltage is below threshold"
            ;;
        SECURITY_MASTER_RESET)
            rebootInitiatedBy="SecutiryReboot"
            otherReason="Reboot due to security master reset has occurred"
            ;;
        CPU_EJTAG_RESET)
            rebootInitiatedBy="CPU EJTAG"
            otherReason="Reboot due to CPU EJTAG reset has occurred"
            ;;
        SCPU_EJTAG_RESET)
            rebootInitiatedBy="SCPU EJTAG"
            otherReason="Reboot due to SCPU EJTAG reset has occurred"
            ;;
        GEN_WATCHDOG_1_RESET)
            rebootInitiatedBy="GEN WatchDog"
            otherReason="Reboot due to gen_watchdog_1 timeout reset has occurred"
            ;;
        AUX_CHIP_EDGE_RESET_0|AUX_CHIP_EDGE_RESET_1)
            rebootInitiatedBy="Aux Chip Edge"
            otherReason="Reboot due to the auxiliary edge-triggered chip reset has occurred"
            ;;
        AUX_CHIP_LEVEL_RESET_0|AUX_CHIP_LEVEL_RESET_1)
            rebootInitiatedBy="Aux Chip Level"
            otherReason="Reboot due to the auxiliary level-triggered chip reset has occurred"
            ;;
        MPM_RESET)
            rebootInitiatedBy="MPM"
            otherReason="Reboot due to the MPM reset has occurred"
            ;;
        *)
            rebootInitiatedBy="Hard Power"
            otherReason="Reboot due to $rebootReason"
            ;;
        esac
}

# Check Hardware registers to log the reason of reset/reboot correctly.
hardPowerCheck()
{
    hw_check=0
    rebootInitiatedBy="Hard Power Reset"
    reasonlogfile=$1

    # Reading the messages.txt file for hardware register reset values.
    if [ -f "$reasonlogfile" ] && [[ $(grep "$PR_STRING" $reasonlogfile) ]]; then
        HWR_ReasonCount=`grep "$PR_STRING" $reasonlogfile | grep  -v "security_dl_sw_reset" | wc -l`
        if [ "$HWR_ReasonCount" -eq "0" ];then
            echo "Hardware Register reset reason information is missing...!!!"
            hw_check=1
        elif [ "$HWR_ReasonCount" -eq "1" ];then
            HWR_Reason=`grep "$PR_STRING" $reasonlogfile | awk '!/security_master_reset|security_dl_sw_reset/ {print toupper($NF)}' | sed 's/\!//g'`
            echo "Hardware register reset reason received as $HWR_Reason"
            customReason="Hardware Register - $HWR_Reason"
            rebootReason="$HWR_Reason"
        else
            #If both power_on_reset and security_master_reset are printed, your script should ignore the security_master_reset.
            if [[ $(grep "power_on_reset" $reasonlogfile) ]]; then
                HWR_FirstReason=`grep "$PR_STRING" $reasonlogfile | awk '!/security_master_reset|security_dl_sw_reset/ {print toupper($NF)}' | head -n1 | sed 's/\!//g'`
                HWR_SecondReason=`grep "$PR_STRING" $reasonlogfile | awk '!/security_master_reset|security_dl_sw_reset/ {print toupper($NF)}' | tail -n1 | sed 's/\!//g'`
            else
                HWR_FirstReason=`grep "$PR_STRING" $reasonlogfile | awk '!/security_dl_sw_reset/ {print toupper($NF)}' | head -n1 | sed 's/\!//g'`
                HWR_SecondReason=`grep "$PR_STRING" $reasonlogfile | awk '!/security_dl_sw_reset/ {print toupper($NF)}' | tail -n1 | sed 's/\!//g'`
            fi

            HWR_PrevReason=`grep -w reason $PREVIOUS_REBOOT_INFO_FILE | awk -F '"' '{print $4}'`
            echo "Previous Hardware Register Reset Reason: HWR_PrevReason=$HWR_PrevReason"
            echo "Current Hardware Register has two reset reasons: HWR_FirstReason=$HWR_FirstReason HWR_SecondReason=$HWR_SecondReason"

            customReason="Hardware Register - $HWR_FirstReason, $HWR_SecondReason"
            if [ "$HWR_FirstReason" != "$HWR_PrevReason" ]; then
                rebootReason="$HWR_FirstReason"
            else
                rebootReason="$HWR_SecondReason"
            fi
        fi
        #Set Other fields for hard reboot information
        echo "Received Hard reboot reason from $reasonlogfile file..."
        setRebootReason $rebootReason
    else
        echo "$reasonlogfile file or $PR_STRING string is missing...!!!"
        hw_check=1
    fi

    return $hw_check
}

lock()
{
    while ! mkdir "$LOCK_DIR" &> /dev/null;do
        echo "Waiting for rebootInfo lock"
        sleep 5
    done
    echo "Acquired rebootInfo lock"
}

unlock()
{
    rm -rf "$LOCK_DIR"
    echo "Releasing rebootInfo lock"
}

##############################
########## Mani APP ##########
##############################

lock

if [ ! -f "${STT_FLAG}" ] || [ ! -f "${REBOOT_INFO_FLAG}" ];then
    echo "Exiting since ${STT_FLAG} or  ${REBOOT_INFO_FLAG} flag is not available"
    unlock
    exit 0
fi

#Creating reboot folder in /opt/secure/ path
if [ ! -d $REBOOT_INFO_DIR ]; then
    echo "Creating $REBOOT_INFO_DIR folder..."
    mkdir $REBOOT_INFO_DIR
fi

#Move previous reboot info files from old build folder to latest folder
if [ -f "$OLD_PREVIOUS_REBOOT_INFO_FILE" ]; then
    echo "Moving $OLD_PREVIOUS_REBOOT_INFO_FILE file to $REBOOT_INFO_DIR..."
    mv $OLD_PREVIOUS_REBOOT_INFO_FILE $PREVIOUS_REBOOT_INFO_FILE
    echo "Remove old $REBOOT_INFO_FILE file from $REBOOT_INFO_DIR..."
    rm -f $REBOOT_INFO_FILE
fi

if [ -f "$OLD_PREVIOUS_HARD_REBOOT_INFO_FILE" ]; then
    echo "Moving $OLD_PREVIOUS_HARD_REBOOT_INFO_FILE file to $REBOOT_INFO_DIR..."
    mv $OLD_PREVIOUS_HARD_REBOOT_INFO_FILE $PREVIOUS_HARD_REBOOT_INFO_FILE
fi

#Check for Firmware Failure cases (ECM Crash, Max reboot etc)
fwFailureCheck
firmware_failure=$?
if [ $firmware_failure -eq 1 ];then
    echo "Firmware failure found..."
    rebootTime=`date -u`
    rebootReason="FIRMWARE_FAILURE"
    setPreviousRebootInfo "$rebootTime" "$rebootInitiatedBy" "$rebootReason" "$customReason" "$otherReason"
else
    # Reading the previous reboot details from /opt/secure/reboot/reboot.info on Bootup
    if [ -f "$REBOOT_INFO_FILE" ];then
        echo "New $REBOOT_INFO_FILE file found, Creating previous reboot info file..."
        mv $REBOOT_INFO_FILE $PREVIOUS_REBOOT_INFO_FILE
    else
        # Reading the previous reboot details from /opt/logs/rebootInfo.log
        echo "$REBOOT_INFO_FILE file not found, Checking from $REBOOT_INFO_LOG_FILE"
        if [ -f "$REBOOT_INFO_LOG_FILE" ];then
            # Parse Previous reboot Info and remove leading space
            rebootInitiatedBy=`grep "PreviousRebootInitiatedBy:" $REBOOT_INFO_LOG_FILE | grep -v grep | awk -F " " '{print $2}'`
            rebootTime=`grep "PreviousRebootTime:" $REBOOT_INFO_LOG_FILE | grep -v grep | awk -F 'PreviousRebootTime:' '{print $2}' | sed 's/^ *//'`
            customReason=`grep "PreviousCustomReason:" $REBOOT_INFO_LOG_FILE | grep -v grep | awk -F " " '{print $2}'`
            otherReason=`grep "PreviousOtherReason:" $REBOOT_INFO_LOG_FILE | grep -v grep | awk -F 'PreviousOtherReason:' '{print $2}' | sed 's/^ *//'`

            echo "Checking Kernel Panic and Hard Power scenarios..."
            # Use current time for kernel crash and hard power reset
            rebootTime=`date -u`            
            if [ "x$rebootInitiatedBy" == "x" ];then
                # Check for Kernel Panic Reboot
                oopsDumpCheck
                kernel_crash=$?
                if [ $kernel_crash -eq 1 ];then
                    rebootReason="KERNEL_PANIC"
                    rebootInitiatedBy="Kernel"
                    otherReason="Reboot due to Kernel Panic captured by Oops Dump"
                else
                    # Check for Hard Power Reboot or reset from Hardware register
                    echo "Checking Hard Power reason using "$NXSERVER_LOG_FILE" file..."
                    hardPowerCheck "$NXSERVER_LOG_FILE"
                    hw_info=$?
                    if [ $hw_info -eq 1 ];then
                        if [ -s "$RESETT_LIST" ];then
                            echo "Checking Hard Power reason using $RESET_LIST file..."
                            rebootReason=`cat "$RESET_LIST" | sed "s/$/_reset/g" | awk '{print toupper($NF)}'`
                            if [ ! -z "$rebootReason" ]; then
                                #Set Other fields for hard reboot information
                                echo "Received Hard reboot reason from $RESET_LIST file..."
                                setRebootReason $rebootReason
                            fi
                        elif [ -f "$KERNEL_LOG_FILE" ] && [[ $(grep "$PR_STRING" $KERNEL_LOG_FILE) ]]; then
                            echo "Checking Hard Power reason using "$KERNEL_LOG_FILE" file..."
                            hardPowerCheck "$KERNEL_LOG_FILE"
                        elif [ -f "$DMESG_LOG_FILE" ] && [[ $(grep "$PR_STRING" $DMESG_LOG_FILE) ]]; then
                            echo "$KERNEL_LOG_FILE file not found, Checking Hard Power reason using "$DMESG_LOG_FILE" file..."
                            hardPowerCheck "$DMESG_LOG_FILE"
                        elif [ -f "$APPLICATION_LOG_FILE" ] && [[ $(grep "$PR_STRING" $APPLICATION_LOG_FILE) ]]; then
                            echo "$KERNEL_LOG_FILE or $DMESG_LOG_FILE file not found, Checking Hard Power reason using "$APPLICATION_LOG_FILE" file..."
                            hardPowerCheck "$APPLICATION_LOG_FILE"
                        else
                            echo "${KERNEL_LOG_FILE} or ${DMESG_LOG_FILE} or ${APPLICATION_LOG_FILE} logfile or $PR_STRING string is missing...!!!"
                            rebootInitiatedBy="Hard Power Reset"
                            customReason="Hardware Register - NULL"
                            otherReason="No information found"
                            rebootReason="HARD_POWER"
                            setPreviousRebootInfo "$rebootTime" "$rebootInitiatedBy" "$rebootReason" "$customReason" "$otherReason"
                            unlock
                            exit 0
                        fi
                    fi
                fi
            else
                if [[ "${APP_TRIGGERED_REASONS[@]}" == *"$rebootInitiatedBy"* ]];then
                    rebootReason="APP_TRIGGERED"
                elif [[ "${OPS_TRIGGERED_REASONS[@]}" == *"$rebootInitiatedBy"* ]];then
                    rebootReason="OPS_TRIGGERED"
                elif [[ "${MAINTENANCE_TRIGGERED_REASONS[@]}" == *"$rebootInitiatedBy"* ]];then
                    rebootReason="MAINTENANCE_REBOOT"
                else
                    rebootReason="FIRMWARE_FAILURE"
                fi
            fi
            setPreviousRebootInfo "$rebootTime" "$rebootInitiatedBy" "$rebootReason" "$customReason" "$otherReason"
        else
            echo "Unable to find the $REBOOT_INFO_LOG_FILE file"
        fi
    fi
fi

# Keypress information
if [ -f "$KEYPRESS_INFO_FILE" ]; then
    cp -f $KEYPRESS_INFO_FILE $PREVIOUS_KEYPRESS_INFO_FILE
    echo "Updated previous keypress info"
else
    echo "Unable to find the $KEYPRESS_INFO_FILE file"
fi

unlock
