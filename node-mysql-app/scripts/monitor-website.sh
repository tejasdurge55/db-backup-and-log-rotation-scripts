#!/bin/bash

URL="http://localhost:3000/health"
EMAIL="your-email@example.com"
LOG_FILE="/var/log/node-mysql-app/monitor.log"

status_code=$(curl --write-out %{http_code} --silent --output /dev/null $URL)

if [[ "$status_code" -ne 200 ]] ; then
  echo "$(date) - Website is down. Status code: $status_code" >> $LOG_FILE
  echo "Subject: Website Alert - Site is down" | sendmail $EMAIL
else
  echo "$(date) - Website is up. Status code: $status_code" >> $LOG_FILE
fi
