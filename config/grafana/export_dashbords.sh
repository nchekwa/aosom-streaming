#!/bin/bash

set -o errexit
set -o pipefail

set -o allexport; 
source ../../.env; 
set +o allexport


FULLURL="http://$GRAFANA_LOGIN:$GRAFANA_PASSWORD@$LOCAL_IP:3000"

set -o nounset

echo "Exporting Grafana dashboards from $LOCAL_IP"
rm -rf dashboards_export
mkdir -p dashboards_export
for dash in $(curl -s "$FULLURL/api/search?query=&" | jq -r '.[] | select(.type == "dash-db") | .uid'); do
        curl -s "$FULLURL/api/dashboards/uid/$dash" | jq -r . > dashboards_export/${dash}.json
        slug=$(cat dashboards_export/${dash}.json | jq -r '.meta.slug')
        jq --arg newval "null" '.dashboard.id |= null' dashboards_export/${dash}.json > dashboards_export/${dash}-idfix.json
        rm dashboards_export/${dash}.json
        mv dashboards_export/${dash}-idfix.json dashboards_export/${dash}-${slug}.json
done


mv dashboards_export/ApstraBlueprints-apstra-aos-blueprint.json dashboards_export/apstra_aos_blueprint.json
mv dashboards_export/ApstraDevices-apstra-aos-device.json dashboards_export/apstra_aos_device.json
mv dashboards_export/ApstraInterfaces-apstra-aos-device-interfaces.json dashboards_export/apstra_aos_interface.json
mv dashboards_export/Syslog-syslog.json dashboards_export/syslog_syslog.json