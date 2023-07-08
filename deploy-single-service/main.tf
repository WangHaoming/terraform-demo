provider "aws" {
    region = "us-east-1"
}


resource "aws_launch_configuration" "example" {
  image_id = "ami-053b0d53c279acc90"
  instance_type = "t2.micro"
  security_groups = [ aws_security_group.instance.id ]
  user_data = <<-EOF
                #! /bin/bash
                echo "Hello, world" > index.html
                nohup busybox httpd -f -p ${var.server_port}&
                EOF
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_vpc" "default" {
    default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name

  min_size = 1
  max_size = 5
  vpc_zone_identifier = data.aws_subnets.default.ids

  # 一台instance启动之后会自动注册到指定target group
  target_group_arns = [ aws_lb_target_group.asg.arn ]
  health_check_type = "ELB"

  tag {
    key = "Name"
    value = "terraform-asg-example"
    propagate_at_launch = true
  }
}

# resource "aws_instance" "example" {
    
#     ami = "ami-053b0d53c279acc90"

#     instance_type =  "t2.micro"
#     tags = {
#      Name = "terraform-example" 
#     }
#     vpc_security_group_ids = [aws_security_group.instance.id]

#     user_data = <<-EOF
#                 #! /bin/bash
#                 echo "Hello, world" > index.html
#                 nohup busybox httpd -f -p ${var.server_port}&
#                 EOF
# }


resource "aws_security_group" "instance"{
    name = "terraform-example-instance"
    ingress {
        from_port = var.server_port
        to_port = var.server_port
        protocol = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 22
        to_port = 22
        protocol = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

variable "server_port" {
    description = "demo variable"
    type = number
    default = 8080
}

# output "public_ip" {
#     value = aws_instance.example.public_ip
#     description = "demo of output"
# }

output "subnet_ids" {
  value = data.aws_subnets.default.ids
}

resource "aws_lb" "examlple" {
  name = "terraform-asg-exapmle"
  load_balancer_type = "application"
  subnets = data.aws_subnets.default.ids
  security_groups = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.examlple.arn
  port = 80
  protocol = "HTTP"

  # return 404 code for default

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code = 404
    }
  }
}


resource "aws_security_group" "alb" {
  name = "terrafrom-example-alb"
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  # 此处必须添加所有出流量? 此处的出流量是为了让ELB的转发请求能到目标主机的，无需设置all 
  egress {
    from_port = var.server_port
    to_port = var.server_port
    protocol = "TCP"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}


resource "aws_lb_target_group" "asg" {
  name = "terrafrom-example-asg"
  port = var.server_port
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default.id
  
  health_check {
    path = "/"
    protocol = "HTTP"
    matcher = "200"
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}


resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

output "alb_dns_name" {
  value = aws_lb.examlple.dns_name
  description = "The domain name of the load balancer"
  
}
