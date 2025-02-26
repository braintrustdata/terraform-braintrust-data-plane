#!/bin/bash

# Mount the local SSD if it exists
MOUNT_DIR="/mnt/tmp/brainstore"
mkdir -p "$MOUNT_DIR"
NVME_DEV=$(lsblk -o NAME,MOUNTPOINT | grep -v MOUNTPOINT | grep nvme1n1 | awk '{print $1}' | head -n 1)
if [ -n "$NVME_DEV" ]; then
  echo "Local SSD detected: $NVME_DEV"

  if ! file -s "/dev/$NVME_DEV" | grep -q "filesystem"; then
    echo "Formatting /dev/$NVME_DEV as ext4..."
    mkfs.ext4 "/dev/$NVME_DEV"
  fi
  echo "Mounting /dev/$NVME_DEV at $MOUNT_DIR..."
  mount "/dev/$NVME_DEV" "$MOUNT_DIR"

  # Add the mount to /etc/fstab to make it persistent.
  # Note this will only survive reboots and not an EC2 stop/start
  if ! grep -q "$MOUNT_DIR" /etc/fstab; then
    echo "/dev/$NVME_DEV $MOUNT_DIR ext4 defaults,nofail 0 2" >> /etc/fstab
  fi
else
  echo "No local SSD detected. Brainstore will use EBS instead."
fi

# Raise the file descriptor limit
cat <<EOF > /etc/security/limits.d/brainstore.conf
# Root users has to be set explicitly
root soft nofile 65535
root hard nofile 65535
# All other users
* soft nofile 65535
* hard nofile 65535
EOF

# Set AWS region for CLI commands
export AWS_DEFAULT_REGION=${aws_region}

apt-get update
apt-get install -y docker.io jq awscli earlyoom dstat
systemctl start docker
systemctl enable docker

# Install CloudWatch agent
arch=$(dpkg --print-architecture)
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/$arch/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb

# Configure CloudWatch agent
cat <<EOF > /opt/aws/amazon-cloudwatch-agent/bin/config.json
{
  "logs": {
    "force_flush_interval": 5,
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/lib/docker/containers/*/*.log",
            "log_group_name": "/braintrust/${deployment_name}/brainstore",
            "log_stream_name": "{instance_id}/containers",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json
sed -i 's/Restart=.*/Restart=always/' /etc/systemd/system/amazon-cloudwatch-agent.service
systemctl daemon-reload
systemctl start amazon-cloudwatch-agent
systemctl enable amazon-cloudwatch-agent

# Get database credentials from Secrets Manager
DB_CREDS=$(aws secretsmanager get-secret-value --secret-id ${database_secret_arn} --query SecretString --output text)
DB_USERNAME=$(echo $DB_CREDS | jq -r .username)
DB_PASSWORD=$(echo $DB_CREDS | jq -r .password)

cat <<EOF > /etc/brainstore.env
# WARNING: Do NOT use quotes around values here. They get passed as literals by docker.
BRAINSTORE_VERBOSE=1
BRAINSTORE_PORT=${brainstore_port}
BRAINSTORE_INDEX_URI=s3://${brainstore_s3_bucket}/brainstore/index
BRAINSTORE_REALTIME_WAL_URI=s3://${brainstore_s3_bucket}/brainstore/wal
BRAINSTORE_LOCKS_URI=redis://${redis_host}:${redis_port}
BRAINSTORE_METADATA_URI=postgres://$DB_USERNAME:$DB_PASSWORD@${database_host}:${database_port}/postgres
BRAINSTORE_WAL_URI=postgres://$DB_USERNAME:$DB_PASSWORD@${database_host}:${database_port}/postgres
BRAINSTORE_CACHE_DIR=/mnt/tmp/brainstore
BRAINSTORE_LICENSE_KEY=${brainstore_license_key}
NO_COLOR=1
AWS_DEFAULT_REGION=${aws_region}
AWS_REGION=${aws_region}
EOF

# Note: This value will be replaced with a specific version when making a release
# FIXME: This should lookup the version from the data file.
BRAINSTORE_RELEASE_VERSION=latest
BRAINSTORE_VERSION_OVERRIDE=${brainstore_version_override}
BRAINSTORE_VERSION=$${BRAINSTORE_VERSION_OVERRIDE:-$${BRAINSTORE_RELEASE_VERSION}}

docker run -d \
  --network host \
  --name brainstore \
  --env-file /etc/brainstore.env \
  --restart always \
  -v /mnt/tmp/brainstore:/mnt/tmp/brainstore \
  public.ecr.aws/braintrust/brainstore:$${BRAINSTORE_VERSION} \
  web
