#!/bin/bash


if [ "$#" -lt 2 ]; then
    usage
fi

METHOD=$1
shift

case $METHOD in
    ipmi)
        # IPMI
        while getopts "i:u:p:c:" opt; do
            case ${opt} in
                i) IPMI_IP=$OPTARG ;;
                u) IPMI_USER=$OPTARG ;;
                p) IPMI_PASS=$OPTARG ;;
                c) IPMI_CMD=$OPTARG ;;
                *) usage ;;
            esac
        done
        
        if [ -z "$IPMI_IP" ] || [ -z "$IPMI_USER" ] || [ -z "$IPMI_PASS" ] || [ -z "$IPMI_CMD" ]; then
            usage
        fi
        
        echo "Executing IPMI command: $IPMI_CMD..."
        case $IPMI_CMD in
            on) ipmitool -I lanplus -H "$IPMI_IP" -U "$IPMI_USER" -P "$IPMI_PASS" power on ;;
            off) ipmitool -I lanplus -H "$IPMI_IP" -U "$IPMI_USER" -P "$IPMI_PASS" power off ;;
            reset) ipmitool -I lanplus -H "$IPMI_IP" -U "$IPMI_USER" -P "$IPMI_PASS" power reset ;;
            *) echo "Invalid IPMI command"; usage ;;
        esac
        ;;
    
    snmp)
        # SNMP
        while getopts "a:c:s:v:o:" opt; do
            case ${opt} in
                a) SNMP_AGENT_IP=$OPTARG ;;
                c) COMMUNITY=$OPTARG ;;
                s) SET_OID=$OPTARG ;;
                v) SNMP_VERSION=$OPTARG ;;
                o) SNMP_VALUE=$OPTARG ;;
                *) usage ;;
            esac
        done
        
        if [ -z "$SNMP_AGENT_IP" ] || [ -z "$COMMUNITY" ] || [ -z "$SET_OID" ] || [ -z "$SNMP_VERSION" ] || [ -z "$SNMP_VALUE" ]; then
            usage
        fi
        
        echo "Sending SNMP set command..."
        snmpset -v "$SNMP_VERSION" -c "$COMMUNITY" "$SNMP_AGENT_IP" "$SET_OID" i "$SNMP_VALUE"
        ;;
    
    redfish)
        # Redfish
        while getopts "r:u:p:a:" opt; do
            case ${opt} in
                r) REDFISH_URL=$OPTARG ;;
                u) REDFISH_USER=$OPTARG ;;
                p) REDFISH_PASS=$OPTARG ;;
                a) REDFISH_ACTION=$OPTARG ;;
                *) usage ;;
            esac
        done
        
        if [ -z "$REDFISH_URL" ] || [ -z "$REDFISH_USER" ] || [ -z "$REDFISH_PASS" ] || [ -z "$REDFISH_ACTION" ]; then
            usage
        fi
        
        echo "Performing Redfish action: $REDFISH_ACTION..."
        case $REDFISH_ACTION in
            On) ACTION_JSON='{"ResetType": "On"}' ;;
            Off) ACTION_JSON='{"ResetType": "ForceOff"}' ;;
            Reset) ACTION_JSON='{"ResetType": "Reset"}' ;;
            *) echo "Invalid Redfish action"; usage ;;
        esac
        
        curl -k -u "$REDFISH_USER:$REDFISH_PASS" -H "Content-Type: application/json" \
            -X POST "$REDFISH_URL/redfish/v1/Systems/1/Actions/ComputerSystem.Reset" \
            -d "$ACTION_JSON"
        ;;
    
    *)
        usage
        ;;
esac
