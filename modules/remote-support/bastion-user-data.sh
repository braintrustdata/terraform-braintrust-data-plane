#!/bin/bash
sudo hostnamectl set-hostname bastion

apt-get update
apt-get install -y jq unzip earlyoom postgresql-client
snap install aws-cli --classic

TPL_REGION="${region}"
TPL_DATABASE_SECRET_ARN="${database_secret_arn}"
TPL_CLICKHOUSE_SECRET_ARN="${clickhouse_secret_arn}"
TPL_REDIS_HOST="${redis_host}"
TPL_REDIS_PORT="${redis_port}"
TPL_DATABASE_HOST="${database_host}"
TPL_CLICKHOUSE_HOST="${clickhouse_host}"

export AWS_REGION=$TPL_REGION
export AWS_DEFAULT_REGION=$TPL_REGION

DB_CREDS=$(aws secretsmanager get-secret-value --secret-id "$TPL_DATABASE_SECRET_ARN" --query SecretString --output text)
DB_USERNAME=$(echo "$DB_CREDS" | jq -r .username)
DB_PASSWORD=$(echo "$DB_CREDS" | jq -r .password)

CLICKHOUSE_PG_URL=""
if [ -n "$TPL_CLICKHOUSE_HOST" ]; then
  CLICKHOUSE_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$TPL_CLICKHOUSE_SECRET_ARN" --query SecretString --output text | jq -r .password)
  CLICKHOUSE_PG_URL="http://default:$CLICKHOUSE_PASSWORD@$TPL_CLICKHOUSE_HOST:8123/default"
fi

# Do NOT use quotes here. Docker will include them as literals.
cat <<EOF > /etc/braintrust.env
export AWS_REGION=$TPL_REGION
export AWS_DEFAULT_REGION=$TPL_REGION
export REDIS_URL=redis://$TPL_REDIS_HOST:$TPL_REDIS_PORT
export PG_URL=postgres://$DB_USERNAME:$DB_PASSWORD@$TPL_DATABASE_HOST/postgres
export CLICKHOUSE_PG_URL=$CLICKHOUSE_PG_URL
EOF

echo -e "\nsource /etc/braintrust.env\n" >> /home/ubuntu/.bashrc

cat <<'EOF' > /home/ubuntu/list-instances.sh
#!/bin/bash
json=$(aws ec2 describe-instances --filters "Name=tag:BraintrustDeploymentName,Values=$TPL_DEPLOYMENT_NAME")

if [ "$1" == "--json" ]; then
  echo "$json"
else
  echo "$json" | jq -r '.Reservations[].Instances[] | "\(.InstanceId) \(.Tags[] | select(.Key=="Name").Value // "")"'
fi

EOF

cat <<'EOF' > /home/ubuntu/list-functions.sh
#!/bin/bash
# Unfortunately we can't support "aws lambda list-functions" because it shows environment variables
# with secrets for their entire account and not just the Braintrust stack. IAM won't let you restrict it.
# This output is generated by Terraform.
%{ for arn in lambda_function_arns ~}
echo "${split(":", arn)[6]} - ${arn}"
%{ endfor ~}
EOF

# Randomly generated key used to jump to other Braintrust instances
mkdir -p /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh
ssh-keygen -t rsa -C "Braintrust Generated Bastion Key" -f /home/ubuntu/.ssh/id_rsa -N ""
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa*

cat <<'EOF' > /home/ubuntu/ec2-connect.sh
#!/bin/bash

json=$(./list-instances.sh --json)
az=$(echo "$json" | jq -r ".AutoScalingGroups[].Instances[] | select(.InstanceId == \"$1\") | .AvailabilityZone")

os_user="ubuntu"
echo "Sending SSH key to instance $os_user@$1"
aws ec2-instance-connect send-ssh-public-key \
  --instance-id "$1" \
  --instance-os-user "$os_user" \
  --ssh-public-key file:///home/ubuntu/.ssh/id_rsa.pub \
  --availability-zone "$az"
echo "Connecting to instance $os_user@$1"
aws ec2-instance-connect ssh \
  --instance-id "$1" \
  --os-user "$os_user" \
  --private-key-file "$HOME/.ssh/id_rsa" \
  --connection-type direct
EOF

chmod +x /home/ubuntu/*.sh
chown ubuntu:ubuntu /home/ubuntu/*.sh
