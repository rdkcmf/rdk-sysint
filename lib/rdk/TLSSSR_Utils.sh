#!/bin/sh

. /etc/include.properties
. /etc/device.properties

TLS_LOG_FILE="$LOG_PATH/tlsError.log"
TLS=""
CURL_TLS_TIMEOUT=30
CURL_TIMEOUT=10
HTTP_CODE=/tmp/curl_httpcode
	
if [ -f /etc/os-release ]; then
    TLS="--tlsv1.2"
fi

tlsLog() {
    echo "$0: $*" >> $TLS_LOG_FILE
}

#TLS Error Logs Functions
logTLSError ()
{
    TLSRet=$1
    server=$2
    case $TLSRet in
        35|51|53|54|58|59|60|64|66|77|80|82|83|90|91)
            tlsLog "HTTPS $TLS failed to connect to $server server with curl error code $TLSRet!!!"
            ;;
    esac
}

# SSR Request Function
sendTLSSSRRequest()
{
    TLSRet=1
    URLENCODE_STRING=""

    if [ "$S3_MD5SUM" != "" ]; then
        URLENCODE_STRING="--data-urlencode \"md5=$S3_MD5SUM\""
    fi

    uploadLog "Attempting $TLS connection to SSR server"
    if [ -f /etc/ssl/certs/staticXpkiCrt.pk12 ]; then
        msg_tls_source="mTLS using static xpki certificate"
        if [ ! -f /usr/bin/GetConfigFile ]; then
            uploadLog "Error: GetConfigFile Not Found"
            exit 127
        fi
        ID="/tmp/.cfgStaticxpki"
        if [ ! -f "$ID" ]; then
            GetConfigFile $ID
        fi
        if [ ! -f "$ID" ]; then
            uploadLog "Error: GetConfigFile failed!!!"
        fi
        CURL_CMD="curl --cert-type P12 --cert /etc/ssl/certs/staticXpkiCrt.pk12:$(cat $ID) -w '%{http_code}\n' -d \"filename=$1\" $URLENCODE_STRING -o \"$FILENAME\" \"$CLOUD_URL\" --connect-timeout $CURL_TLS_TIMEOUT -m 10"
    fi

    uploadLog "Connect with $msg_tls_source CURL_CMD: `echo "$CURL_CMD" | sed -e 's#devicecert_1.*-w#devicecert_1.pk12<hidden key> -w#g' | sed -e 's#staticXpkiCrt.*-w#staticXpkiCrt.pk12<hiddenkey> -w#g'`"
    eval $CURL_CMD > $HTTP_CODE
    TLSRet=$?

    logTLSError $TLSRet "SSR"
    uploadLog "Connect with $msg_tls_source CURL_CMD: return code : $TLSRet"
}
