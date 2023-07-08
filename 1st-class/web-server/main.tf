provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "example" {
    
    ami = "ami-053b0d53c279acc90"

    instance_type =  "t2.micro"
    tags = {
     Name = "web-server" 
    }
    vpc_security_group_ids = [aws_security_group.nstance-sg-1.id]

    user_data = <<-EOF
                #! /bin/bash
                echo "Hello, world" > index.html
                nohup busybox httpd -f -p ${var.server_port}&
                EOF
}

resource "aws_security_group" "instance-sg-1"{
    name = "web-service"
    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
    }
}