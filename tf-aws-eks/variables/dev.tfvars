aws_region      = "us-east-1"
environment     = "dev"
vpc_name        = "eks-vpc"
cluster_name    = "my-eks-cluster-dev"
vpc_cidr        = "192.168.0.0/16"
public_subnets  = ["192.168.1.0/24", "192.168.2.0/24", "192.168.3.0/24"]
private_subnets = ["192.168.4.0/24", "192.168.5.0/24", "192.168.6.0/24"]
instance_type   = "t3.small"
cluster_version = "1.36"
# Restrict this to your own public IPv4 address/CIDR before deploying.
cluster_endpoint_public_access_cidrs = ["203.0.113.10/32"]
