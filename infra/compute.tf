# ------------------------------------------------------------------
# IAM role for EC2 and Lambda
#
# NOTE: the original sandbox deployment used AWS Academy's built-in
# LabRole, which grants broad permissions. This is fine for a training
# sandbox but is NOT a least-privilege setup. The role below is a
# placeholder with the same effective permissions the app needs
# (S3 read/write, RDS network access, CloudWatch Logs) — in a real
# deployment this should be scoped down to specific bucket/table ARNs.
# ------------------------------------------------------------------

resource "aws_iam_role" "app_role" {
  name = var.ec2_iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = ["ec2.amazonaws.com", "lambda.amazonaws.com"] }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.app_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess" # scope down in production
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.app_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess" # scope down in production
}

resource "aws_iam_instance_profile" "app_profile" {
  name = "image-app-instance-profile"
  role = aws_iam_role.app_role.name
}

# ------------------------------------------------------------------
# Application Load Balancer
# ------------------------------------------------------------------

resource "aws_lb" "app" {
  name               = "image-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app.id]
  subnets            = [for s in aws_subnet.public : s.id]

  tags = { Name = "image-app-alb" }
}

resource "aws_lb_target_group" "app" {
  name     = "image-app-tg"
  port     = var.flask_app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    port                = tostring(var.flask_app_port)
    healthy_threshold   = 5
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    matcher             = "200-299"
  }

  tags = { Name = "image-app-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ------------------------------------------------------------------
# Launch Template + Auto Scaling Group
#
# The AMI and user_data are placeholders — the original deployment
# installed Flask + dependencies manually via EC2 Instance Connect.
# A production version would bake a custom AMI or use a proper
# user_data bootstrap script referencing web-app/ from this repo.
# ------------------------------------------------------------------

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "image-app-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.app_profile.name
  }

  vpc_security_group_ids = [aws_security_group.app.id]

  # Placeholder bootstrap — installs dependencies and starts the Flask
  # app. In production this would pull from a build artifact rather
  # than cloning/copying source at boot time.
  user_data = base64encode(<<-EOF
    #!/bin/bash
    sudo yum install -y python3-pip
    pip3 install flask boto3 mysql-connector-python google-generativeai werkzeug
    # copy app code / systemd service setup would go here
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "image-app-instance" }
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "image-app-asg"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity
  vpc_zone_identifier = [aws_subnet.private.id]
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "image-app-asg-instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "image-app-cpu-scaling"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}
