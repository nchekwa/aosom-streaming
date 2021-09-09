#!/bin/bash
set -e

INFLUXDB_ORG_ID=`curl --silent -k -X GET \
        "http://influxdb:8086/api/v2/orgs" \
        -H "Authorization: Token ${INFLUXDB_ADMIN_TOKEN}" \
        -H "Content-type: application/json" | sed 's/^[ \t]*//;s/[ \t]*$//' | tr -d '\n' | sed -E 's/.*"id": "?([^,"]*)","name": "'"${INFLUXDB_ORG}"'"?.*/\1/' `

echo "Collect INFLUXDB_ORG_ID based on name: $INFLUXDB_ORG"
echo $INFLUXDB_ORG_ID

echo "Create new syslog buckets... "
curl --silent -k -X POST \
"http://influxdb:8086/api/v2/buckets" \
--header "Authorization: Token ${INFLUXDB_ADMIN_TOKEN}" \
--header "Content-type: application/json" \
--data '{
            "orgID": "'"$INFLUXDB_ORG_ID"'",
            "name": "syslog",
            "retentionRules": [
            {
                "type": "expire",
                "everySeconds": 7776000,
                "shardGroupDurationSeconds": 0
            }
            ]
        }'

if [ "${1:0:1}" = '-' ]; then
    set -- telegraf "$@"
fi

exec "$@"