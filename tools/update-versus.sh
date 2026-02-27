#!/bin/bash

#
# This script can be used on the production server to update the versus repository,
# compress the content and setup permissions for all plugins that require it.
#

cd /srv/versus
sudo -u www-data git restore .
sudo -u www-data git pull
sudo chmod +x /srv/versus/tools/discord-process-errors.sh
