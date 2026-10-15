variable "aws_region" {
  description = "The region where the infrastructure should be deployed to"
  type        = string
}

variable "environment" {
  description = "Deployment environment used for resource naming and tags"
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "vpc_name" {
  description = "VPC Name for Jenkins Server VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR for Jenkins Server VPC"
  type        = string
}

variable "public_subnets" {
  description = "Subnets CIDR range"
  type        = list(string)
}

variable "instance_type" {
  description = "Instance Type"
  type        = string
}

variable "jenkins_security_group" {
  description = "Instance Type"
  type        = string
}

variable "jenkins_ec2_instance" {
  description = "Instance Type"
  type        = string
}

variable "key_pair_name" {
  description = "Existing EC2 key pair name used to connect to the Jenkins host"
  type        = string
  validation {
    condition     = !startswith(var.key_pair_name, "REPLACE_WITH_")
    error_message = "key_pair_name must reference an existing EC2 key pair."
  }
}

variable "instance_profile_name" {
  description = "Existing IAM instance profile for Jenkins AWS access"
  type        = string
  validation {
    condition     = !startswith(var.instance_profile_name, "REPLACE_WITH_")
    error_message = "instance_profile_name must reference an existing IAM instance profile."
  }
}

variable "admin_cidrs" {
  description = "IPv4 CIDR ranges allowed to access Jenkins HTTP and SSH"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for cidr in var.admin_cidrs : cidr != "203.0.113.10/32"
    ])
    error_message = "Replace the documentation-only 203.0.113.10/32 CIDR with an approved administrator CIDR."
  }
}
