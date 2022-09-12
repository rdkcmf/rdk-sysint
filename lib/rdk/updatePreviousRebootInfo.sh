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

# Source Variable
. /etc/device.properties
if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

# Define logfiles and flags
REBOOT_INFO_LOG_FILE="/opt/logs/rebootInfo.log"
KERNEL_LOG_FILE="/opt/logs/messages.txt"
UIMGR_LOG_FILE="/opt/logs/PreviousLogs/uimgr_log.txt"
OCAPRI_LOG_FILE="/opt/logs/PreviousLogs/ocapri_log.txt"
ECM_CRASH_LOG_FILE="/opt/logs/PreviousLogs/messages-ecm.txt"
PSTORE_CONSOLE_LOG_FILE="/sys/fs/pstore/console-ramoops-0"
KERNEL_PANIC_SEARCH_STRING="PREVIOUS_KERNEL_OOPS_DUMP"
KERNEL_PANIC_SEARCH_STRING_01="Kernel panic - not syncing"
KERNEL_PANIC_SEARCH_STRING_02="Oops - undefined instruction"
KERNEL_PANIC_SEARCH_STRING_03="Oops - bad syscall"
KERNEL_PANIC_SEARCH_STRING_04="branch through zero"
KERNEL_PANIC_SEARCH_STRING_05="unknown data abort code"
KERNEL_PANIC_SEARCH_STRING_06="Illegal memory access"
ECM_CRASH_SEARCH_STRING="\*\*\*\* CRASH \*\*\*\*"
MAX_REBOOT_STRING="Box has rebooted 10 times"
POWERON_STRING="POWER_ON"
REBOOT_INFO_DIR="/opt/secure/reboot"
REBOOT_INFO_FILE="/opt/secure/reboot/reboot.info"
KEYPRESS_INFO_FILE="/opt/secure/reboot/keypress.info"
PREVIOUS_REBOOT_INFO_FILE="/opt/secure/reboot/previousreboot.info"
PREVIOUS_HARD_REBOOT_INFO_FILE="/opt/secure/reboot/hardpower.info"
PREVIOUS_KEYPRESS_INFO_FILE="/opt/secure/reboot/previouskeypress.info"
STT_FLAG="/tmp/stt_received"
REBOOT_INFO_FLAG="/tmp/rebootInfo_Updated"
UPDATE_REBOOT_INFO_INVOKED_FLAG="/tmp/Update_rebootInfo_invoked"
LOCK_DIR="/tmp/rebootInfo.lock"
AMLOGIC_SYSFS_FILE="/sys/devices/platform/aml_pm/reset_reason"
BRCM_REBOOT_FILE="/proc/brcm/previous_reboot_reason"
RTK_REBOOT_FILE="/proc/cmdline"

#Use log framework to pring timestamp and source script name
rebootLog()
{
    echo "$0: $*"
}

rebootLog "Start of Reboot Reason Script"

# Define Reasons for APP_TRIGGERED, OPS_TRIGGERED and MAINTENANCE_TRIGGERED cases
APP_TRIGGERED_REASONS=(Servicemanager systemservice_legacy WarehouseReset WarehouseService HrvInitWHReset HrvColdInitReset HtmlDiagnostics InstallTDK StartTDK TR69Agent SystemServices Bsu_GUI SNMP CVT_CDL Nxserver DRM_Netflix_Initialize hrvinit PaceMFRLibrary)
OPS_TRIGGERED_REASONS=(ScheduledReboot RebootSTB.sh FactoryReset UpgradeReboot_firmwareDwnld.sh UpgradeReboot_restore XFS wait_for_pci0_ready websocketproxyinit NSC_IR_EventReboot host_interface_dma_bus_wait usbhotplug Receiver_MDVRSet Receiver_VidiPath_Enabled Receiver_Toggle_Optimus S04init_ticket Network-Service monitor.sh ecmIpMonitor.sh monitorMfrMgr.sh vlAPI_Caller_Upgrade ImageUpgrade_rmf_osal ImageUpgrade_mfr_api ImageUpgrade_updateNewImage.sh ImageUpgrade_userInitiatedFWDnld.sh ClearSICache tr69hostIfReset hostIf_utils hostifDeviceInfo HAL_SYS_Reboot UpgradeReboot_deviceInitiatedFWDnld.sh UpgradeReboot_ipdnl.sh PowerMgr_Powerreset PowerMgr_coldFactoryReset DeepSleepMgr PowerMgr_CustomerReset PowerMgr_PersonalityReset Power_Thermmgr PowerMgr_Plat HAL_CDL_notify_mgr_event vldsg_estb_poll_ecm_operational_state BcmIndicateEcmReset SASWatchDog BP3_Provisioning eMMC_FW_UPGRADE BOOTLOADER_UPGRADE cdl_service BCMCommandHandler BRCM_Image_Validate docsis_mode_check.sh tch_nvram.sh Receiver)
MAINTENANCE_TRIGGERED_REASONS=(AutoReboot.sh PwrMgr)

# Save the reboot info with all the fields
setPreviousRebootInfo()
{
    # Set Previous reboot info file with received reboot reason.
    timestamp=$1
    source=$2
    reason=$3
    custom=$4
    other=$5
    # Get Previous Hard Power reset information
    if [ ! -z $PREVIOUS_REBOOT_INFO_FILE ]; then
        rebootLog "Reboot reason present in $PREVIOUS_REBOOT_INFO_FILE file:"
        cat $PREVIOUS_REBOOT_INFO_FILE
    fi
    rebootLog "Updating Reboot reason in $PREVIOUS_REBOOT_INFO_FILE file"
    echo "{" > $PREVIOUS_REBOOT_INFO_FILE
    echo "\"timestamp\":\"$timestamp\"," >> $PREVIOUS_REBOOT_INFO_FILE
    echo "\"source\":\"$source\"," >> $PREVIOUS_REBOOT_INFO_FILE
    echo "\"reason\":\"$reason\"," >> $PREVIOUS_REBOOT_INFO_FILE
    echo "\"customReason\":\"$custom\"," >> $PREVIOUS_REBOOT_INFO_FILE
    echo "\"otherReason\":\"$other\"" >> $PREVIOUS_REBOOT_INFO_FILE
    echo "}" >> $PREVIOUS_REBOOT_INFO_FILE

    # Set Hard Power reset time with timestamp
    if [ "$reason" == "HARD_POWER" ] || [ "$reason" == "POWER_ON_RESET" ] || [ "$reason" == "UNKNOWN_RESET" ] || [ ! -f "$PREVIOUS_HARD_REBOOT_INFO_FILE" ];then
        echo "{" > $PREVIOUS_HARD_REBOOT_INFO_FILE
        echo "\"lastHardPowerReset\":\"$timestamp\"" >> $PREVIOUS_HARD_REBOOT_INFO_FILE
        echo "}" >> $PREVIOUS_HARD_REBOOT_INFO_FILE
        rebootLog "Updated Hard Power Reboot Time stamp"
    fi

    rebootLog "Updated Previous Reboot Reason information"
}

# Check for Firmware Failure
fwFailureCheck()
{
    fw_failure=0
    rebootLog "Checking firmware failure cases (ECM Crash, Max Reboot etc)..."

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

    if [ "$SOC" = "BRCM" ]; then
        # Ensure OOPS DUMP string presence for Kernel Panic in messages.txt
        if [ -f "$KERNEL_LOG_FILE" ] && [[ $(grep $KERNEL_PANIC_SEARCH_STRING $KERNEL_LOG_FILE) ]];then
            if [[ $(grep -e "Kernel Oops" -e "Kernel Panic" $KERNEL_LOG_FILE) ]];then
                oops_dump=1
            fi
        fi
    elif [ "$SOC" = "RTK" ] || [ "$RDK_PROFILE" = "TV" ]; then
        #Check KERNEL PANIC, OOPS DUMP string presence for Kernel Panic in /sys/fs/pstore/console-ramoops-0
        if [ -f "$PSTORE_CONSOLE_LOG_FILE" ]; then
            if [[ $(grep "$KERNEL_PANIC_SEARCH_STRING_01" $PSTORE_CONSOLE_LOG_FILE) ]];then
                oops_dump=1
            elif [[ $(grep "$KERNEL_PANIC_SEARCH_STRING_02" $PSTORE_CONSOLE_LOG_FILE) ]];then
                oops_dump=1
            elif [[ $(grep "$KERNEL_PANIC_SEARCH_STRING_03" $PSTORE_CONSOLE_LOG_FILE) ]];then
                oops_dump=1
            elif [[ $(grep "$KERNEL_PANIC_SEARCH_STRING_04" $PSTORE_CONSOLE_LOG_FILE) ]];then
                oops_dump=1
            elif [[ $(grep "$KERNEL_PANIC_SEARCH_STRING_05" $PSTORE_CONSOLE_LOG_FILE) ]];then
                oops_dump=1
            elif [[ $(grep "$KERNEL_PANIC_SEARCH_STRING_06" $PSTORE_CONSOLE_LOG_FILE) ]];then
                oops_dump=1
            else
                oops_dump=0
            fi

            if [ "$oops_dump" -eq "1" ];then
                for pstorefile in /sys/fs/pstore/*
                do
                    filename=$(basename "${pstorefile}")
                    cat $pstorefile > /opt/logs/${filename}.log
                done
                rebootLog "Please check pstore logs(/sys/fs/pstore/*) for more detail about kerenl panic !"
            fi
        fi
    fi

    return $oops_dump
}

# Applicable only for AMLOGIC platforms where we read SysRootfs data for Reset value
setResetReason()
{
    resetVal=$1

    case $resetVal in
        0)
            rebootInitiatedBy="POWER_ON_REBOOT"
            resetReason="POWER_ON_RESET"
            customReason="COLD_BOOT"
            otherReason="Reboot due to hardware powere cable unplug"
            ;;
        1)
            rebootInitiatedBy="SOFTWARE_REBOOT"
            resetReason="SOFTWARE_MASTER_RESET"
            customReason="NORMAL_BOOT"
            otherReason="Reboot due to user triggered reboot command"
            ;;
        2)
            rebootInitiatedBy="FACTORY_RESET_REBOOT"
            resetReason="FACTORY_RESET"
            customReason="FACTORY_RESET"
            otherReason="Reboot due to factory reset reboot"
            ;;
        3)
            rebootInitiatedBy="UPGRADE_SYSTEM_REBOOT"
            resetReason="UPDATE_BOOT"
            customReason="UPDATE_BOOT"
            otherReason="Reboot due to system upgrade reboot"
            ;;
        4)
            rebootInitiatedBy="FASTBOOT_REBOOT"
            resetReason="FAST_BOOT"
            customReason="FAST_BOOT"
            otherReason="Reboot due to fast reboot"
            ;;
        5)
            rebootInitiatedBy="SUSPEND_REBOOT"
            resetReason="SUSPEND_BOOT"
            customReason="SUSPEND_BOOT"
            otherReason="Reboot due to suspend reboot"
            ;;
        6)
            rebootInitiatedBy="HIBERNATE_REBOOT"
            resetReason="HIBERNATE_BOOT"
            customReason="HBERNATE_BOOT"
            otherReason="Reboot due to hibernate reboot"
            ;;
        7)
            rebootInitiatedBy="BOOTLOADER_REBOOT"
            resetReason="FASTBOOT_BOOTLOADER"
            customReason="FASTBOOT_BOOTLOADER"
            otherReason="Reboot due to fastboot boootloader reboot"
            ;;
        8)
            rebootInitiatedBy="SHUTDOWN_REBOOT"
            resetReason="SHUTDOWN_REBOOT"
            customReason="SHUTDOWN_REBOOT"
            otherReason="Reboot due to shutdown"
            ;;
        9)
            rebootInitiatedBy="RPMPB"
            resetReason="RPMPB_REBOOT"
            customReason="RPMPB_REBOOT"
            otherReason="Reboot due to RPMPB"
            ;;
       10)
            rebootInitiatedBy="THERMAL"
            resetReason="THERMAL_REBOOT"
            customReason="THERMAL_REBOOT"
            otherReason="Reboot due to thermal value"
            ;;
       11)
            rebootInitiatedBy="CRASH_DUMP"
            resetReason="CRASH_REBOOT"
            customReason="CRASH_REBOOT"
            otherReason="Reboot due to crash dump"
            ;;
       12)
            rebootInitiatedBy="KernelPanic"
            resetReason="KERNEL_PANIC"
            customReason="KERNEL_PANIC"
            otherReason="Reboot due to oops dump caused panic"
            ;;
       13)
            rebootInitiatedBy="WATCH_DOG"
            resetReason="WATCHDOG_REBOOT"
            customReason="WATCHDOG_REBOOT"
            otherReason="Reboot due to watch dog timer"
            ;;
       14)
            rebootInitiatedBy="STR_AUTH_FAIL"
            resetReason="AMLOGIC_DDR_SHA2_REBOOT"
            customReason="AMLOGIC_DDR_SHA2_REBOOT"
            otherReason="Reboot due to STR Authorization failure"
            ;;
       15)
            rebootInitiatedBy="FFV"
            resetReason="FFV_REBOOT"
            customReason="FFV_REBOOT"
            otherReason="Reboot due to Reserved FFV"
            ;;
        *)
            rebootInitiatedBy="HARD_POWER_RESET"
            resetReason="UNKNOWN_RESET"
            customReason="UNKNOWN"
            otherReason="Reboot due to unknown reason"
            ;;
    esac
}

#Read the HW Register value of  PreviousRebootReason and set details.
setRebootReason()
{
    rebootReason=$1
    case $rebootReason in
        SOFTWARE|SOFTWARE_MASTER_RESET)
            rebootInitiatedBy="SoftwareReboot"
            rebootReason="SOFTWARE_MASTER_RESET"
            t2CountNotify "Test_SWReset"
            otherReason="Reboot due to user triggered reboot command"
            ;;
        WATCHDOG|WATCHDOG_TIMER_RESET)
            rebootInitiatedBy="WatchDog"
            rebootReason="WATCHDOG_TIMER_RESET"
            otherReason="Reboot due to watch dog timer reset"
            ;;
        HARDWARE|POWER_ON_RESET)
            rebootInitiatedBy="PowerOn"
            rebootReason="POWER_ON_RESET"
            otherReason="Reboot due to unplug of power cable from the STB"
            ;;
        MAIN_CHIP_INPUT_RESET)
            rebootInitiatedBy="Main Chip"
            rebootReason="MAIN_CHIP_INPUT_RESET"
            otherReason="Reboot due to chip's main reset input has been asserted"
            ;;
        MAIN_CHIP_RESET_INPUT)
            rebootInitiatedBy="Main Chip"
            rebootReason="MAIN_CHIP_RESET_INPUT"
            otherReason="Reboot due to chip's main reset input has been asserted"
            ;;
        TAP_IN_SYSTEM_RESET)
            rebootInitiatedBy="Tap-In System"
            rebootReason="TAP_IN_SYSTEM_RESET"
            otherReason="Reboot due to the chip's TAP in-system reset has been asserted"
            ;;
        FRONT_PANEL_4SEC_RESET)
            rebootInitiatedBy="FrontPanel Button"
            rebootReason="FRONT_PANEL_RESET"
            otherReason="Reboot due to the front panel 4 second reset has been asserted"
            ;;
        S3_WAKEUP_RESET)
            rebootInitiatedBy="Standby Wakeup"
            rebootReason="S3_WAKEUP_RESET"
            otherReason="Reboot due to the chip woke up from deep standby"
            ;;
        SMARTCARD_INSERT_RESET)
            rebootInitiatedBy="SmartCard Insert"
            rebootReason="SMARTCARD_INSERT_RESET"
            otherReason="Reboot due to the smartcard insert reset has occurred"
            ;;
        OVERHEAT|OVERTEMP_RESET)
            rebootInitiatedBy="OverTemperature"
            rebootReason="OVERTEMP_RESET"
            otherReason="Reboot due to chip temperature is above threshold (125*C)"
            ;;
        OVERVOLTAGE_1_RESET|OVERVOLTAGE_RESET)
            rebootInitiatedBy="OverVoltage"
            rebootReason="OVERVOLTAGE_RESET"
            otherReason="Reboot due to chip voltage is above threshold"
            ;;
        PCIE_1_HOT_BOOT_RESET|PCIE_0_HOT_BOOT_RESET)
            rebootInitiatedBy="PCIE Boot"
            rebootReason="PCIE_HOT_BOOT_RESET"
            otherReason="Reboot due to PCIe hot boot reset has occurred"
            ;;
        UNDERVOLTAGE_1_RESET|UNDERVOLTAGE_0_RESET|UNDERVOLTAGE_RESET)
            rebootInitiatedBy="LowVoltage"
            rebootReason="UNDERVOLTAGE_RESET"
            otherReason="Reboot due to chip voltage is below threshold"
            ;;
        SECURITY_MASTER_RESET)
            rebootInitiatedBy="SecutiryReboot"
            rebootReason="SECURITY_MASTER_RESET"
            otherReason="Reboot due to security master reset has occurred"
            ;;
        CPU_EJTAG_RESET)
            rebootInitiatedBy="CPU EJTAG"
            rebootReason="CPU_EJTAG_RESET"
            otherReason="Reboot due to CPU EJTAG reset has occurred"
            ;;
        SCPU_EJTAG_RESET)
            rebootInitiatedBy="SCPU EJTAG"
            rebootReason="SCPU_EJTAG_RESET"
            otherReason="Reboot due to SCPU EJTAG reset has occurred"
            ;;
        GEN_WATCHDOG_1_RESET)
            rebootInitiatedBy="GEN WatchDog"
            rebootReason="GEN_WATCHDOG_RESET"
            otherReason="Reboot due to gen_watchdog_1 timeout reset has occurred"
            ;;
        AUX_CHIP_EDGE_RESET_0|AUX_CHIP_EDGE_RESET_1)
            rebootInitiatedBy="Aux Chip Edge"
            rebootReason="AUX_CHIP_EDGE_RESET"
            otherReason="Reboot due to the auxiliary edge-triggered chip reset has occurred"
            ;;
        AUX_CHIP_LEVEL_RESET_0|AUX_CHIP_LEVEL_RESET_1)
            rebootInitiatedBy="Aux Chip Level"
            rebootReason="AUX_CHIP_LEVEL_RESET"
            otherReason="Reboot due to the auxiliary level-triggered chip reset has occurred"
            ;;
        MPM_RESET)
            rebootInitiatedBy="MPM"
            rebootReason="MPM_RESET"
            otherReason="Reboot due to the MPM reset has occurred"
            ;;
        *)
            rebootInitiatedBy="Hard Power"
            rebootReason="$rebootReason"
            otherReason="Reboot due to $rebootReason"
            ;;
        esac
}

#Perform locking of script execution to avoid parallel execution
lock()
{
    while ! mkdir "$LOCK_DIR" &> /dev/null;do
        rebootLog "Waiting for rebootInfo lock"
        sleep 5
    done
    rebootLog "Acquired rebootInfo lock"
}

#Unlock before exiting the script
unlock()
{
    rm -rf "$LOCK_DIR"
    rebootLog "Releasing rebootInfo lock"
}

#Check for STT and Reboot Checker flag before updating reboot reason
CheckSTT()
{
    rebootLog "Checking ${STT_FLAG} and ${REBOOT_INFO_FLAG} flag to update the reboot reason"
    if [ ! -f "${STT_FLAG}" ] || [ ! -f "${REBOOT_INFO_FLAG}" ];then
        rebootLog "Exiting since ${STT_FLAG} or  ${REBOOT_INFO_FLAG} flag is not available"
        unlock
        rebootLog "End of Reboot Reason Script"
        exit 0
    fi
}

#Fucntion to update reboot reason when hardware register is empty
exitforNullrebootreason()
{
    rebootInitiatedBy="Hard Power Reset"
    customReason="Hardware Register - NULL"
    otherReason="No information found"
    rebootReason="HARD_POWER"
    setPreviousRebootInfo "$rebootTime" "$rebootInitiatedBy" "$rebootReason" "$customReason" "$otherReason"
    unlock
    rebootLog "End of Reboot Reason Script"
    exit 0
}

# Check Hardware registers to log the reason of reset/reboot correctly.
hardPowerCheck()
{
    hard_reason_file=$1

    # Reading the proc file for hardware register reset values.
    if [ "$hard_reason_file" == "$BRCM_REBOOT_FILE" ]; then
        # Check for /proc/brcm/previousrebootreason file entry present in rootfs
        HWR_Info=`cat $hard_reason_file | tr '[a-z]' '[A-Z]'`
        HWR_ReasonCount=`echo $HWR_Info | awk -F',' '{print NF}'`
        rebootLog "Hardware Register Info file $hard_reason_file has hard reboot information"
        if [ "$HWR_ReasonCount" -eq "1" ];then # Found one hard reboot reason
            HWR_Reason="$HWR_Info"
            rebootLog "Hardware register reset reason received as $HWR_Reason"
            customReason="Hardware Register - $HWR_Reason"
            rebootReason="$HWR_Reason"
        elif [ "$HWR_ReasonCount" -eq "2" ];then
            #Ignore main_chip_reset and security_master_reset for hard power plug reboot if these strings are populated with power_on_reset.
            HWR_Reason=`echo $HWR_Info | awk -F ',' '{print $1}'`
            HWR_ExtraReason=`echo $HWR_Info | awk -F ',' '{print $2}'`
            rebootLog "Hardware register reset reason received as $HWR_Reason, $HWR_ExtraReason"
            customReason="Hardware Register - $HWR_Reason, $HWR_ExtraReason"
            rebootReason="$HWR_Reason"
        fi
    elif [ "$hard_reason_file" == "$RTK_REBOOT_FILE" ]; then
        HWR_Info=`cat $hard_reason_file`
        HWR_ReasonCount=`echo $HWR_Info | grep "wakeupreason" | wc -l`
        if [ "$HWR_ReasonCount" -eq "1" ];then
            HWR_Reason=`echo ${HWR_Info#*wakeupreason=} | cut -d' ' -f1 | tr '[a-z]' '[A-Z]'`
            rebootReason="$HWR_Reason"
        fi
    fi

    #Set Other fields for hard reboot information
    setRebootReason $rebootReason
}

##############################
########## Main APP ##########
##############################

lock

#check for first time invocation flag and proceed for script execution
if [ "$DEVICE_NAME" = "PLATCO" ] || [ "$DEVICE_NAME" = "LLAMA" ];then
    if [ -f "${UPDATE_REBOOT_INFO_INVOKED_FLAG}" ];then
        rebootLog "${UPDATE_REBOOT_INFO_INVOKED_FLAG} flag found"
        CheckSTT
    else
        rebootLog "${UPDATE_REBOOT_INFO_INVOKED_FLAG} not found, proceeding..."
    fi
else
    CheckSTT
fi

#Creating reboot folder in /opt/secure/ path
if [ ! -d $REBOOT_INFO_DIR ]; then
    rebootLog "Creating $REBOOT_INFO_DIR folder..."
    mkdir $REBOOT_INFO_DIR
fi

# Use current time to report the kernel crash and hard power reset
rebootTimestamp=`date -u`

# Read and Move /opt/secure/reboot/reboot.info as /opt/secure/reboot/previousreboot.info
if [ -f "$REBOOT_INFO_FILE" ];then
    rebootLog "New $REBOOT_INFO_FILE file found, Creating previous reboot info file..."
    cat $REBOOT_INFO_FILE
    mv $REBOOT_INFO_FILE $PREVIOUS_REBOOT_INFO_FILE
else
    rebootLog "$REBOOT_INFO_FILE file not found, Assigning default values..."
    # Set following variables to NULL before using them
    rebootInitiatedBy=""
    rebootTime=""
    customReason=""
    otherReason=""

    # Reading the previous reboot details from /opt/logs/rebootInfo.log
    if [ -f "$REBOOT_INFO_LOG_FILE" ];then
        rebootLog "$REBOOT_INFO_LOG_FILE logfile found, Fetching source, time and other reasons"
        # Parse Previous reboot Info and remove leading space
        rebootInitiatedBy=`grep "PreviousRebootInitiatedBy:" $REBOOT_INFO_LOG_FILE | grep -v grep | awk -F "PreviousRebootInitiatedBy:" '{print $2}' | sed 's/^ *//'`
        rebootTime=`grep "PreviousRebootTime:" $REBOOT_INFO_LOG_FILE | grep -v grep | awk -F 'PreviousRebootTime:' '{print $2}' | sed 's/^ *//'`
        customReason=`grep "PreviousCustomReason:" $REBOOT_INFO_LOG_FILE | grep -v grep | awk -F "PreviousCustomReason:" '{print $2}' | sed 's/^ *//'`
        otherReason=`grep "PreviousOtherReason:" $REBOOT_INFO_LOG_FILE | grep -v grep | awk -F 'PreviousOtherReason:' '{print $2}' | sed 's/^ *//'`
    fi

    rebootLog "Validating reboot information received from $REBOOT_INFO_LOG_FILE..."
    if [ "x$rebootInitiatedBy" == "x" ];then
        rebootLog "$REBOOT_INFO_LOG_FILE file not found and Value of rebootInitiatedBy=$rebootInitiatedBy is empty"
        rebootTime="$rebootTimestamp"
        # Check for Kernel Panic Reboot
        rebootLog "Checking for OOPS DUMP for Kernel Panic..."
        oopsDumpCheck
        kernel_crash=$?
        if [ $kernel_crash -eq 1 ];then
            rebootReason="KERNEL_PANIC"
            rebootInitiatedBy="Kernel"
            customReason="Hardware Register - KERNEL_PANIC"
            otherReason="Reboot due to Kernel Panic captured by Oops Dump"
        else
            # Reading hard reset values from sysfs
            if [ "$DEVICE_NAME" = "PLATCO" ] || [ "$DEVICE_NAME" = "LLAMA" ];then
                rebootLog "Using $AMLOGIC_SYSFS_FILE to fetch hard reboot reason for AMLOGIC TV platforms"
                resetvalue=`cat $AMLOGIC_SYSFS_FILE`
                setResetReason $resetvalue
                customReason="Hardware Register - $customReason"
                rebootReason="$resetReason"
            elif [ "$SOC" = "BRCM" ]; then
                # For RDKV BROADCOM platforms, we will be getting hard reboot reason from /proc/brcm/previous_reboot_reason files
                rebootLog "Checking for HARD POWER Reboot Scenarios..."
                rebootInitiatedBy="Hard Power Reset"
                if [ -f $BRCM_REBOOT_FILE ] && [[ $(cat $BRCM_REBOOT_FILE) ]];then
                    rebootLog "Checking Hard Power reason using "$BRCM_REBOOT_FILE" file..."
                    hardPowerCheck "$BRCM_REBOOT_FILE"
                else
                    # Exit script by setting hard reboot reason as NULL
                    rebootLog "$BRCM_REBOOT_FILE file not found or Hard Power Reboot info is missing!!!"
                    exitforNullrebootreason
                fi
            elif [ "$SOC" = "RTK" ] || [ "$RDK_PROFILE" = "TV" ]; then
                #Reading the /proc/cmdline to check wakeup reason on Realtek & TV Platform.
                if [ -f $RTK_REBOOT_FILE ] && [[ $(grep "wakeupreason" $RTK_REBOOT_FILE) ]]; then
                    rebootLog "Checking Hard Power reason using "$RTK_REBOOT_FILE" file..."
                    hardPowerCheck "$RTK_REBOOT_FILE"
                    customReason="Hardware Register - $rebootReason"
                else
                    # Exit script by setting hard reboot reason as NULL
                    rebootLog "$RTK_REBOOT_FILE file not found or Hard Power Reboot info is missing!!!"
                    exitforNullrebootreason
                fi
            fi
        fi
    else
        rebootLog "$REBOOT_INFO_LOG_FILE logfile found and received source of rebootInitiatedBy=$rebootInitiatedBy"
        # Assign reboot reason by comparing the rebootInitiatedBy with APP_TRIGGERED_REASONS/OPS_TRIGGERED_REASONS/MAINTENANCE_TRIGGERED_REASONS
        if [[ "${APP_TRIGGERED_REASONS[@]}" == *"$rebootInitiatedBy"* ]];then
            rebootReason="APP_TRIGGERED"
            # Assign reboot reason as MAINTENANCE_REBOOT if customReason is passed as MAINTENANCE_REBOOT
            if [ $customReason == "MAINTENANCE_REBOOT" ];then
                 rebootReason="MAINTENANCE_REBOOT"
            fi
        elif [[ "${OPS_TRIGGERED_REASONS[@]}" == *"$rebootInitiatedBy"* ]];then
            rebootReason="OPS_TRIGGERED"
        elif [[ "${MAINTENANCE_TRIGGERED_REASONS[@]}" == *"$rebootInitiatedBy"* ]];then
            rebootReason="MAINTENANCE_REBOOT"
        else
            rebootReason="FIRMWARE_FAILURE"
        fi
    fi

    # FIRMWARE FAILURE is of high priority for all the STB platforms and not applicable for TV platforms
    # We have to report it before updating any soft/hard reboot scenarios
    # Check for FIRMWARE FAILURE cases (ECM Crash, Max reboot etc) for STB platforms
    if [ "$DEVICE_NAME" != "PLATCO" ] || [ "$DEVICE_NAME" != "LLAMA" ];then
        fwFailureCheck
        firmware_failure=$?
        if [ $firmware_failure -eq 1 ];then
            rebootLog "Firmware failure found..."
            rebootReason="FIRMWARE_FAILURE"
        else
            rebootLog "Firmware failure not found..."
        fi
    fi
    #Update reboot information in /opt/secure/reboot/previousreboot.info file
    setPreviousRebootInfo "$rebootTime" "$rebootInitiatedBy" "$rebootReason" "$customReason" "$otherReason"
fi

# Keypress information
if [ -f "$KEYPRESS_INFO_FILE" ]; then
    cp -f $KEYPRESS_INFO_FILE $PREVIOUS_KEYPRESS_INFO_FILE
    rebootLog "Updated previous keypress info"
else
    rebootLog "Unable to find the $KEYPRESS_INFO_FILE file"
fi

# Create flag to ensure updatePreviousRebootInfo.sh script is invoked
if [ ! -f "$UPDATE_REBOOT_INFO_INVOKED_FLAG" ];then
    touch $UPDATE_REBOOT_INFO_INVOKED_FLAG
fi

if [ -f $STT_FLAG ]; then
    rebootLog "Update previous reboot info to Parodus"
    sh /lib/rdk/updateRebootInfoToParodus.sh
fi

rebootLog "End of Reboot Reason Script"
unlock
