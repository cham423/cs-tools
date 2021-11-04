#!/bin/bash
# author: cham423
apt -y install ufw jq
ufw allow ssh
ufw default deny incoming
ufw default allow outgoing
for ip in $(curl https://ip-ranges.amazonaws.com/ip-ranges.json | jq '.prefixes[] | select(.service? == "CLOUDFRONT") | .ip_prefix?' | tr -d '"'); do ufw allow proto tcp from $ip to any port 80,443; done
ufw enable
