#!/bin/bash

echo "Starting local test server..."

echo "Starting SRCDS..."

./srcds -console -game garrysmod +maxplayers 20 +gamemode versus +map exp_c18_v1_alpha033 +host_workshop_collection 3674693854
