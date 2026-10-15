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

variable "private_subnets" {
  description = "Subnets CIDR range"
  type        = list(string)
}

variable "instance_type" {
  description = "Instance Type"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version supported by EKS in the selected region"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "my-eks-cluster"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "IPv4 CIDRs allowed to reach the EKS public API endpoint"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for cidr in var.cluster_endpoint_public_access_cidrs : cidr != "203.0.113.10/32"
    ])
    error_message = "Replace the documentation-only 203.0.113.10/32 CIDR with an approved administrator or Jenkins egress CIDR."
  }
}
