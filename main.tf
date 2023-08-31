module "vpc" {

  source = "shamimice03/vpc/aws"

  vpc_name = "prometheus"
  cidr     = "10.2.0.0/16"

  azs                 = ["ap-northeast-1a", "ap-northeast-1c"]
  public_subnet_cidr  = ["10.2.0.0/20", "10.2.16.0/20"]
  private_subnet_cidr = ["10.2.32.0/20", "10.2.48.0/20"]

  enable_dns_hostnames      = true
  enable_dns_support        = true
  enable_single_nat_gateway = false

  tags = {
    "Team" = "devops"
    "Env"  = "dev"
  }
}

resource "aws_security_group" "ssh_access" {
  name        = "SSH-Access"
  description = "Allow SSH"
  vpc_id      = module.vpc.vpc_id

  dynamic "ingress" {
    for_each = [22]
    iterator = port
    content {
      description = "Allow SSH"
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "prometheus_sg" {
  name        = "prometheus sg"
  description = "SG for prometheus server"
  vpc_id      = module.vpc.vpc_id

  dynamic "ingress" {
    for_each = [9090]
    iterator = port
    content {
      description = "Allow from port ${port.value}"
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "application_sg" {
  name        = "application sg"
  description = "SG for application server"
  vpc_id      = module.vpc.vpc_id

  dynamic "ingress" {
    for_each = [9100]
    iterator = port
    content {
      description     = "Allow from port ${port.value}"
      from_port       = port.value
      to_port         = port.value
      protocol        = "tcp"
      security_groups = [aws_security_group.prometheus_sg.id]
    }
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# module "prometheus_server" {
#   source = "terraform-aws-modules/ec2-instance/aws"

#   name = "prometheus"

#   instance_type          = "t2.micro"
#   key_name               = "ec2-access"
#   monitoring             = false
#   vpc_security_group_ids = [aws_security_group.public_sg.id]
#   subnet_id              = module.vpc.public_subnet_id[0]
#   #iam_instance_profile   = module.instance_profile.profile_name
#   user_data = file("${path.module}/prometheus_setup.sh")

#   tags = {
#     Terraform   = "true"
#     Environment = "dev"
#   }
# }


# module "prometheus_server" {
#   source = "terraform-aws-modules/ec2-instance/aws"

#   name = "prometheus"

#   instance_type          = "t2.micro"
#   key_name               = "ec2-access"
#   monitoring             = false
#   vpc_security_group_ids = [aws_security_group.public_sg.id]
#   subnet_id              = module.vpc.public_subnet_id[0]
#   #iam_instance_profile   = module.instance_profile.profile_name
#   user_data = file("${path.module}/prometheus_setup.sh")
# }

data "aws_ami" "amazonlinux2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*-hvm-*"]
  }
}

resource "aws_instance" "prometheus_server" {
  ami                    = data.aws_ami.amazonlinux2.id
  instance_type          = "t2.micro"
  key_name               = "ec2-access"
  vpc_security_group_ids = [aws_security_group.ssh_access.id, aws_security_group.prometheus_sg.id]
  subnet_id              = module.vpc.public_subnet_id[0]
  #iam_instance_profile   = module.instance_profile.profile_name
  user_data = file("${path.module}/prometheus_setup.sh")

  tags = {
    Name        = "prometheus-server"
    Environment = "dev"
  }
}

resource "aws_instance" "application_server" {
  ami                    = data.aws_ami.amazonlinux2.id
  instance_type          = "t2.micro"
  key_name               = "ec2-access"
  vpc_security_group_ids = [aws_security_group.ssh_access.id, aws_security_group.application_sg.id]
  subnet_id              = module.vpc.public_subnet_id[0]
  #iam_instance_profile   = module.instance_profile.profile_name
  user_data = file("${path.module}/node_exporter_setup.sh")

  tags = {
    Name        = "application-server"
    Environment = "dev"
  }
}

