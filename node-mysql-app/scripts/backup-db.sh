#!/bin/bash

DB_USER="node_user"
DB_PASSWORD="secure_password"
DB_NAME="node_app"
BACKUP_DIR="/home/ubuntu/backups"
DATE=$(date +%Y%m%d_%H%M%S)
AWS_BUCKET="your-s3-bucket-name"

mkdir -p $BACKUP_DIR

mysqldump -u$DB_USER -p$DB_PASSWORD $DB_NAME | gzip > $BACKUP_DIR/$DB_NAME-$DATE.sql.gz

aws s3 cp $BACKUP_DIR/$DB_NAME-$DATE.sql.gz s3://$AWS_BUCKET/db-backups/

find $BACKUP_DIR -name "*.sql.gz" -type f -mtime +7 -delete
