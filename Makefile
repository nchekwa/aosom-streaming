VAR_FILE=.env
include $(VAR_FILE)

.SILENT:
.PHONY: help

# Based on https://gist.github.com/prwhite/8168133#comment-1313022

## This help screen
help:
	printf "Available targets\n\n"
	awk '/^[a-zA-Z\-\_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "%-30s %s\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)

## Install all components
install:
REQUIRED_BINS := jq
$(foreach bin,$(REQUIRED_BINS),\
    $(if $(shell command -v $(bin) 2> /dev/null),,$(error Please install `$(bin)`)))

## Start all components
start: install
	@echo "-- Start all components --"
	docker-compose up -d

## Stop all components
stop:
	@echo "-- Stop all components --"
	@docker-compose down

## Create datasources (proxy) in grafana and load Dashboards (grafana-create-source-proxy grafana-load-dashboards)
init: grafana-create-source-proxy grafana-load-dashboards

## Create datasource in proxy mode in Grafana
grafana-create-source-proxy:
	@echo "-- Cleanup Datasources in Grafana"
	@curl 'http://$(GRAFANA_LOGIN):$(GRAFANA_PASSWORD)@localhost:3000/api/datasources/1' -X DELETE -H 'Content-Type: application/json' -H 'Accept: application/json'
	@curl 'http://$(GRAFANA_LOGIN):$(GRAFANA_PASSWORD)@localhost:3000/api/datasources/2' -X DELETE -H 'Content-Type: application/json' -H 'Accept: application/json'
	@echo ""
	@echo "-- Create Datasource in Grafana 1/3 [InfluxDB]"
	@curl 'http://$(GRAFANA_LOGIN):$(GRAFANA_PASSWORD)@localhost:3000/api/datasources' -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{"id":"1", "name":"influxdb","type":"influxdb","url":"http://influxdb:8086","access":"proxy","isDefault":false,"database":"aos","method": "POST", "user":"$(INFLUXDB_ADMIN_USER)","jsonData":{"httpMode":"POST"}, "secureJsonData":{"password":"${INFLUXDB_ADMIN_PASSWORD}"}}'
	@echo ""
	@echo "-- Create Datasource in Grafana 2/3 [Prometheus]"
	@curl 'http://$(GRAFANA_LOGIN):$(GRAFANA_PASSWORD)@localhost:3000/api/datasources' -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{"id":"2", "name":"prometheus","type":"prometheus","url":"http://prometheus:9090","access":"proxy","isDefault":true}'
	@echo ""
	@echo "-- Create Datasource in Grafana 3/3 [Loki]"
	@curl 'http://$(GRAFANA_LOGIN):$(GRAFANA_PASSWORD)@localhost:3000/api/datasources' -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{"id":"3", "name":"loki","type":"loki","url":"http://loki:3100","access":"proxy","isDefault":false}'
	@echo ""

## Create datasource in direct mode in Grafana (use that is grafana cannot access the data)
grafana-create-source-direct:
	@echo "-- Cleanup Datasources in Grafana"
	@curl 'http://$(GRAFANA_LOGIN):$(GRAFANA_PASSWORD)@localhost:3000/api/datasources/1' -X DELETE -H 'Content-Type: application/json' -H 'Accept: application/json'
	@curl 'http://$(GRAFANA_LOGIN):$(GRAFANA_PASSWORD)@localhost:3000/api/datasources/2' -X DELETE -H 'Content-Type: application/json' -H 'Accept: application/json'
	@echo ""
	@echo "-- Create Datasource in Grafana 1/3 [InfluxDB]"
	@curl 'http://$(GRAFANA_LOGIN):$(GRAFANA_PASSWORD)@localhost:3000/api/datasources' -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{"name":"influxdb","type":"influxdb","url":"http://$(LOCAL_IP):8086","access":"direct","isDefault":false,"database":"aos","user":"$(INFLUXDB_ADMIN_USER)","password":"$(INFLUXDB_ADMIN_PASSWORD)"}'
	@echo ""
	@echo "-- Create Datasource in Grafana 2/3 [Prometheus]"
	@curl 'http://$(GRAFANA_LOGIN):$(GRAFANA_PASSWORD)@localhost:3000/api/datasources' -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{"name":"prometheus","type":"prometheus","url":"http://$(LOCAL_IP):9090","access":"direct","isDefault":true}'
	@echo ""
	@echo "-- Create Datasource in Grafana 3/3 [Loki]"
	@curl 'http://$(GRAFANA_LOGIN):$(GRAFANA_PASSWORD)@localhost:3000/api/datasources' -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{"name":"loki","type":"loki","url":"http://$(LOCAL_IP):3100","access":"direct","isDefault":true}'
	@echo ""

## Load/Reload the Dashboards in Grafana
grafana-load-dashboards:
	@echo "-- Load Dashboard in Grafana AOS Blueprint"
	@curl 'http://$(GRAFANA_LOGIN):$(GRAFANA_PASSWORD)@localhost:3000/api/dashboards/db' -X POST -H "Content-Type: application/json" --data-binary @config/grafana/dashboards/apstra_aos_blueprint.json
	@echo ""
	@echo "-- Load Dashboard in Grafana AOS Device"
	@curl 'http://$(GRAFANA_LOGIN):$(GRAFANA_PASSWORD)@localhost:3000/api/dashboards/db' -X POST -H "Content-Type: application/json" --data-binary @config/grafana/dashboards/apstra_aos_device.json
	@echo ""
	@echo "-- Load Dashboard in Grafana AOS Interface"
	@curl 'http://$(GRAFANA_LOGIN):$(GRAFANA_PASSWORD)@localhost:3000/api/dashboards/db' -X POST -H "Content-Type: application/json" --data-binary @config/grafana/dashboards/apstra_aos_interface.json
	@echo ""
	@echo "-- Load Dashboard in Grafana Syslog Dashboard"
	@curl 'http://$(GRAFANA_LOGIN):$(GRAFANA_PASSWORD)@localhost:3000/api/dashboards/db' -X POST -H "Content-Type: application/json" --data-binary @config/grafana/dashboards/syslog_syslog.json
	@echo ""

sleep:
	sleep 3

## Stop all components, Update all images, Restart all components, Reload the Dashboards (stop update-docker start grafana-load-dashboards)
update: stop update-docker start sleep grafana-load-dashboards

## Update Docker Images
update-docker:
	@echo "-- Download Latest Images from Docker Hub --"
	@docker-compose pull --ignore-pull-failures

## Delete Grafana information and delete current streaming session on AOS (clean-docker clean-aos)
clean: clean-docker clean-aos

## Delete Docker Volume information (grafana_data, prometheus_data, influxdb_data, chronograf_data)
clean-docker:
	@echo "-- Delete all Volume Data"
	@echo "-- Grafana (Grafana must be stopped) --"
	docker volume rm -f aosom-streaming_grafana_data
	@echo "-- Prometheus (Prometheus must be stopped) --"
	docker volume rm -f aosom-streaming_prometheus_data
	@echo "-- InfluxDB (InfluxDB must be stopped) --"
	docker volume rm -f aosom-streaming_influxdb_data
	@echo "-- Chronograf (Chronograf must be stopped) --"
	docker volume rm -f aosom-streaming_chronograf_data
	@echo "-- Loki (Loki must be stopped) --"
	docker volume rm -f aosom-streaming_loki_data

AOS_TOKEN := $(shell  curl --silent -k -X POST "https://${AOS_SERVER}/api/user/login" -H  "accept: application/json" -H  "content-type: application/json, Cache-Control:no-cache" -d "{ \"username\":\"${AOS_LOGIN}\", \"password\":\"${AOS_PASSWORD}\" }" | jq --raw-output '.token') 
AOS_STREAM_RECEIVER = $(shell  curl --silent -k -X GET "https://${AOS_SERVER}/api/streaming-config"   -H  "accept: application/json"   -H "AuthToken: ${AOS_TOKEN}"  | jq -r -c '.items[] | select(.hostname == "${LOCAL_IP}") | .id' |  tr '\n', " ") 
## Delete Apstra streaming receivers 
clean-aos:
	@echo "-- Apstra AOS Clean --"
	@echo "-- Delete Steam Receivers via API from ${AOS_SERVER} (AOS server must be reacheable) --"
	for receiver_id in $(AOS_STREAM_RECEIVER); do \
        echo "-- Delete Apstra Steam Receiver ID: $$receiver_id "; \
		curl -k -X DELETE "https://${AOS_SERVER}/api/streaming-config/$$receiver_id"   -H  "accept: application/json"   -H "AuthToken: ${AOS_TOKEN}"; \
		echo "--- Done"; \
    done