resource "aws_launch_template" "brainstore" {
  name          = "${var.deployment_name}-brainstore"
  image_id      = data.aws_ami.ubuntu_24_04.id
  instance_type = var.instance_type
  key_name      = var.instance_key_pair_name

  iam_instance_profile {
    arn = aws_iam_instance_profile.brainstore.arn
  }

  vpc_security_group_ids = [var.security_group_id]

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 200
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh.tpl", {
    aws_region                  = data.aws_region.current.name
    deployment_name             = var.deployment_name
    database_secret_arn         = var.database_secret_arn
    database_host               = var.database_host
    database_port               = var.database_port
    redis_host                  = var.redis_host
    redis_port                  = var.redis_port
    brainstore_port             = var.port
    brainstore_s3_bucket        = aws_s3_bucket.brainstore.id
    brainstore_license_key      = var.license_key
    brainstore_version_override = var.version_override == null ? "" : var.version_override
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.deployment_name}-brainstore"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "${var.deployment_name}-brainstore"
    }
  }

  tag_specifications {
    resource_type = "network-interface"
    tags = {
      Name = "${var.deployment_name}-brainstore"
    }
  }
}

resource "aws_lb" "brainstore" {
  name               = "${var.deployment_name}-brainstore"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids
  security_groups    = [var.security_group_id]

  lifecycle {
    # Changing security groups requires a new NLB.
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "brainstore" {
  name        = "${var.deployment_name}-brainstore"
  port        = var.port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    protocol            = "TCP"
    port                = var.port
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 10
  }
}

resource "aws_lb_listener" "brainstore" {
  load_balancer_arn = aws_lb.brainstore.arn
  port              = var.port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.brainstore.arn
  }
}

resource "aws_autoscaling_group" "brainstore" {
  name_prefix         = "${var.deployment_name}-brainstore"
  min_size            = var.instance_count
  max_size            = var.instance_count * 2
  desired_capacity    = var.instance_count
  vpc_zone_identifier = var.private_subnet_ids
  health_check_type   = "EC2"
  # This is essentially the expected boot and setup time of the instance.
  # If too low, the ASG may terminate the instance before it has a chance to boot.
  health_check_grace_period = 60
  target_group_arns         = [aws_lb_target_group.brainstore.arn]

  launch_template {
    id      = aws_launch_template.brainstore.id
    version = "$Latest"
  }

  lifecycle {
    # If this ever has to be replaced, we want a new ASG to be created before the old one is terminated.
    create_before_destroy = true
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
      max_healthy_percentage = 200
    }
  }
}

data "aws_ami" "ubuntu_24_04" {
  most_recent = true

  # Canonical's AWS account for official Ubuntu images.
  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-*-24.04-arm64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}
