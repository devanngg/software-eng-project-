# We'll be using publicly available modules for creating different services instead of resources
# https://registry.terraform.io/browse/modules?provider=aws

# Creating a VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.21.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs                     = data.aws_availability_zones.azs.names
  public_subnets          = var.public_subnets
  map_public_ip_on_launch = true

  enable_dns_hostnames = true

  tags = {
    Name        = var.vpc_name
    Terraform   = "true"
    Environment = var.environment
  }

  public_subnet_tags = {
    Name = "jenkins-subnet"
  }
}

resource "aws_security_group" "jenkins" {
  name        = var.jenkins_security_group
  description = "Restricted access to Jenkins host"
  vpc_id      = module.vpc.vpc_id

  dynamic "ingress" {
    for_each = var.admin_cidrs
    content {
      description = "Jenkins web from approved admin network"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }
  dynamic "ingress" {
    for_each = var.admin_cidrs
    content {
      description = "SSH from approved admin network"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.8.0"

  name = var.jenkins_ec2_instance

  instance_type               = var.instance_type
  ami                         = data.aws_ami.amazon-linux.id
  key_name                    = var.key_pair_name
  iam_instance_profile        = var.instance_profile_name
  monitoring                  = true
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  user_data                   = file("../scripts/install_build_tools.sh")
  availability_zone           = data.aws_availability_zones.azs.names[0]

  tags = {
    Name        = "Jenkins-Server"
    Terraform   = "true"
    Environment = var.environment
  }
}
