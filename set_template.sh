#!/bin/sh

curl -XPUT 'http://localhost:9200/_template/filebeat' -d@./filebeat.template.json
