#!/bin/bash

# The following tags are required:
#   rackuuid - all resources related to the deployment should have the same tag
#              (eg. example.com-20160301)

# The following IAM roles are required:
#   AmazonS3ReadOnlyAccess
#   AmazonEC2ReadOnlyAccess

if [ ! -d `getent passwd magento | cut -d: -f6`/.ssh/ ];
then
  mkdir `getent passwd magento | cut -d: -f6`/.ssh/
  chown magento:magento `getent passwd magento | cut -d: -f6`/.ssh/
  restorecon -R `getent passwd magento | cut -d: -f6`/.ssh/
fi

region=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone/ | sed '$ s/.$//'`
uuid=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
keybucket=`/bin/aws ec2 describe-tags --region ${region} --filters "Name=resource-id,Values=${uuid}" "Name=key,Values=rackuuid" --query 'Tags[*].Value[]' --output text`

while [ -z ${bucketexist} ]
do
  bucketexist=`/bin/aws s3 ls | grep "${keybucket}\-lsynckey"`
  sleep 5
done

if [ ! -z ${keybucket} ]
then
  /bin/aws s3 cp s3://${keybucket}-lsynckey/magento-admin.pub `getent passwd magento | cut -d: -f6`/.ssh/
  cat `getent passwd magento | cut -d: -f6`/.ssh/magento-admin.pub >> `getent passwd magento | cut -d: -f6`/.ssh/authorized_keys
  rm -f `getent passwd magento | cut -d: -f6`/.ssh/magento-admin.pub
  chown magento:magento `getent passwd magento | cut -d: -f6`/.ssh/magento-admin.pub `getent passwd magento | cut -d: -f6`/.ssh/authorized_keys
  restorecon -R `getent passwd magento | cut -d: -f6`/.ssh/
fi
