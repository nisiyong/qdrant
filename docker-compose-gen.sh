#!/usr/bin/env bash

set -euo pipefail

declare NODES="${1:-5}"
declare BASE_PORT="${2:-6330}"

cat <<-EOF
version: "3.7"

services:
EOF

for ((node=0; node<NODES; node++))
do
	declare SERVICE_NAME=qdrant_node_$node

	declare HTTP_PORT=$((BASE_PORT + node * 10 + 3))
	declare GRPC_PORT=$((BASE_PORT + node * 10 + 4))

	if ((node == 0))
	then
		declare COMMAND="./qdrant --uri 'http://$SERVICE_NAME:6335'"
	else
		declare COMMAND="bash -c \"sleep $((10 + node / 10 + RANDOM % 10)) && ./qdrant --bootstrap 'http://qdrant_node_0:6335' --uri 'http://$SERVICE_NAME:6335'\""
	fi

	cat <<-EOF
	  $SERVICE_NAME:
	    image: qdrant/qdrant:latest
	    command: $COMMAND
	    restart: always
	    environment:
	      - QDRANT__LOG_LEVEL=info
	      - QDRANT__SERVICE__GRPC_PORT=6334
	      - QDRANT__CLUSTER__P2P__PORT=6335
	      - QDRANT__CLUSTER__ENABLED=true
	      - QDRANT__CLUSTER__CONSENSUS__MAX_MESSAGE_QUEUE_SIZE=5000
	    ports:
	      - "127.0.0.1:$HTTP_PORT:6333"
	      - "127.0.0.1:$GRPC_PORT:6334"
	    deploy:
	      resources:
	        limits:
	          cpus: "0.03"

	EOF
done
