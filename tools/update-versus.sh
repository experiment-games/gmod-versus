#!/bin/bash

#
# This script can be used on the production server to update the versus repository,
# compress the content and setup permissions for all plugins that require it.
#

cd /srv/versus
eval "$(ssh-agent -s)"
ssh-add /home/<your username>/.ssh/<your private key>
git restore .
git pull
sudo chmod +x /srv/versus/tools/discord-process-errors.sh
sudo chown -R www-data:www-data /srv/versus/
