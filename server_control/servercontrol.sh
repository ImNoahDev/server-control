#!/bin/bash


usage() {
    echo "Usage: $0 [method] [action] [options]"
    echo "Methods:"
    echo "  ipmi    - Use IPMI to control the server or get sensor data"
    echo "  snmp    - Use SNMP to control the server or get sensor data"
    echo "  redfish - Use Redfish to control the server or get sensor data"
    echo ""
    echo "Actions:"
    echo "  power_on   - Power on the server"
    echo "  power_off  - Power off the server"
    echo "  reset      - Reset the server"
    echo "  sensor_data - Get sensor data"
    echo ""
    echo "Options:"
    echo "  For IPMI: -i <IPMI_IP> -u <USERNAME> -p <PASSWORD> [-c <COMMAND>]"
    echo "    COMMAND: on|off|reset|sensor_data"
    echo ""
    echo "  For SNMP: -a <SNMP_AGENT_IP> -c <COMMUNITY> -s <SET_OID> -v <SNMP_VERSION> [-o <VALUE>] [-d]"
    echo "    VALUE: 1 to power on, 0 to power off"
    echo "    -d: Get sensor data"
    echo ""
    echo "  For Redfish: -r <REDFISH_URL> -u <USERNAME> -p <PASSWORD> [-a <ACTION>] [-d]"
    echo "    ACTION: On|Off|Reset"
    echo "    -d: Get sensor data"
    exit 1
}

# Ensure at least three arguments are provided
if [ "$#" -lt 3 ]; then
    usage
fi

METHOD=$1
ACTION=$2
shift 2

case $METHOD in
    ipmi)
        # IPMI arguments
        while getopts "i:u:p:c:" opt; do
            case ${opt} in
                i) IPMI_IP=$OPTARG ;;
                u) IPMI_USER=$OPTARG ;;
                p) IPMI_PASS=$OPTARG ;;
                c) IPMI_CMD=$OPTARG ;;
                *) usage ;;
            esac
        done
        
        if [ -z "$IPMI_IP" ] || [ -z "$IPMI_USER" ] || [ -z "$IPMI_PASS" ]; then
            usage
        fi

        case $ACTION in
            power_on) ipmitool -I lanplus -H "$IPMI_IP" -U "$IPMI_USER" -P "$IPMI_PASS" power on ;;
            power_off) ipmitool -I lanplus -H "$IPMI_IP" -U "$IPMI_USER" -P "$IPMI_PASS" power off ;;
            reset) ipmitool -I lanplus -H "$IPMI_IP" -U "$IPMI_USER" -P "$IPMI_PASS" power reset ;;
            sensor_data) ipmitool -I lanplus -H "$IPMI_IP" -U "$IPMI_USER" -P "$IPMI_PASS" sdr list ;;
            *) echo "Invalid action"; usage ;;
        esac
        ;;
    
    snmp)
        # SNMP arguments
        while getopts "a:c:s:v:o:d" opt; do
            case ${opt} in
                a) SNMP_AGENT_IP=$OPTARG ;;
                c) COMMUNITY=$OPTARG ;;
                s) SET_OID=$OPTARG ;;
                v) SNMP_VERSION=$OPTARG ;;
                o) SNMP_VALUE=$OPTARG ;;
                d) GET_SENSOR_DATA=1 ;;
                *) usage ;;
            esac
        done
        
        if [ -z "$SNMP_AGENT_IP" ] || [ -z "$COMMUNITY" ] || [ -z "$SNMP_VERSION" ]; then
            usage
        fi
        
        if [ -n "$GET_SENSOR_DATA" ]; then
            echo "Getting sensor data via SNMP..."
            snmpwalk -v "$SNMP_VERSION" -c "$COMMUNITY" "$SNMP_AGENT_IP" 
        else
            if [ -z "$SET_OID" ] || [ -z "$SNMP_VALUE" ]; then
                usage
            fi
            echo "Sending SNMP set command..."
            snmpset -v "$SNMP_VERSION" -c "$COMMUNITY" "$SNMP_AGENT_IP" "$SET_OID" i "$SNMP_VALUE"
        fi
        ;;
    
    redfish)
        # Redfish arguments
        while getopts "r:u:p:a:d" opt; do
            case ${opt} in
                r) REDFISH_URL=$OPTARG ;;
                u) REDFISH_USER=$OPTARG ;;
                p) REDFISH_PASS=$OPTARG ;;
                a) REDFISH_ACTION=$OPTARG ;;
                d) GET_SENSOR_DATA=1 ;;
                *) usage ;;
            esac
        done
        
        if [ -z "$REDFISH_URL" ] || [ -z "$REDFISH_USER" ] || [ -z "$REDFISH_PASS" ]; then
            usage
        fi
        
        if [ -n "$GET_SENSOR_DATA" ]; then
            echo "Getting sensor data via Redfish..."
            curl -k -u "$REDFISH_USER:$REDFISH_PASS" "$REDFISH_URL/redfish/v1/Chassis/1/Sensors"
        else
            if [ -z "$REDFISH_ACTION" ]; then
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
        fi
        ;;
    
    *)
        usage
        ;;
esac
