#!/bin/sh

. /etc/include.properties
logsFile=$LOG_PATH/ipVideoAnalytics.log
CERT_PATH="/etc/ssl/certs/rdkv-va-cpe-clnt.xcal.tv.cert.pem"
CONFIG_PATH="/tmp/atdjivoqkkci"

echo "`/bin/timestamp` IP video analytics " >> $logsFile

XB_LANIP=`route -n | grep 'UG[ \t]'  | awk '{print $2}' | head -n1 | awk '{print $1;}'`
if [ -z "$XB_LANIP" ]; then
        echo "[MTLS_VA] Unable to retrive gateway ip. Exiting from script" >> $logsFile
        exit 1
fi
echo "[MTLS_VA] XB_LANIP : $XB_LANIP" >> $logsFile
echo -e $XB_LANIP va-cpe-srvr.xcal.tv >> /etc/hosts

if [ -d /etc/ssl/certs ]; then
        if [ ! -f /usr/bin/GetConfigFile ];then
                echo "Error: GetConfigFile Not Found" >> $logsFile
                exit 127
        fi
        GetConfigFile $CONFIG_PATH
fi

if [ -f "/etc/webui/certs/comcast-rdk-ca-chain.cert.pem" ];then
        CA_FILE_PATH="/etc/webui/certs/comcast-rdk-ca-chain.cert.pem"
else
        CA_FILE_PATH="/etc/ssl/trmclient/comcast-rdk-ca-chain.cert.pem"
fi

echo "[MTLS_VA] mTLS Video Analytics request" >> $logsFile
CURL_CMD="curl -w '%{http_code}\n' --key $CONFIG_PATH --cert $CERT_PATH "https://va-cpe-srvr.xcal.tv:58081/test/OddEvenPattern.test" --cacert $CA_FILE_PATH -o /tmp/OddEvenPattern.test"
HTTP_CODE=`curl -w '%{http_code}\n' --key $CONFIG_PATH --cert $CERT_PATH "https://va-cpe-srvr.xcal.tv:58081/test/OddEvenPattern.test" --cacert $CA_FILE_PATH -o /tmp/OddEvenPattern.test`
http_code=$(echo "$HTTP_CODE" | awk -F\" '{print $1}' )
echo "[MTLS_VA] CURL_CMD: $CURL_CMD" >> $logsFile
echo "[MTLS_VA] http_code $http_code" >> $logsFile

if [ "$http_code" == 200 ]; then
        echo "[MTLS_VA] mTLS curl command successfull with http code: $http_code" >> $logsFile
else
        echo "[MTLS_VA] mTLS curl command failed with http code: $http_code" >> $logsFile
fi

if [ -f $CONFIG_PATH ]; then
        rm -rf $CONFIG_PATH
fi

echo "`/bin/timestamp` Exiting from IP video analytics " >> $logsFile
