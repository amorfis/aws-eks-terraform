terraform {
  required_version = ">= 0.11.8"
}

variable "access_key" {}
variable "secret_key" {}
variable "region" {
  default = "eu-west-1"
}
variable "awsctl-profile" {}

provider "aws" {
  version = ">= 1.47.0"
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region  = "${var.region}"
}

data "aws_availability_zones" "available" {}

locals {
  cluster_name = "test-eks-from-tf"
  tags = {
    Environment = "private eks"
  }
}

module "vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  version            = "1.14.0"
  name               = "eks-test-vpc"
  cidr               = "10.0.0.0/16"
  azs                = ["${data.aws_availability_zones.available.names[0]}", "${data.aws_availability_zones.available.names[1]}", "${data.aws_availability_zones.available.names[2]}"]
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true
  tags               = "${merge(local.tags, map("kubernetes.io/cluster/${local.cluster_name}", "shared"))}"
}

module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  cluster_name = "eks-cluster-created-with-tf"
  subnets      = ["${module.vpc.private_subnets}"]
  vpc_id       = "${module.vpc.vpc_id}"

  kubeconfig_aws_authenticator_env_variables = {
    AWS_PROFILE = "${var.awsctl-profile}"
  }

  worker_groups = [
    {
      instance_type = "t2.large"
      asg_desired_capacity = "2"
      asg_max_size  = 2
    }
  ]

  tags = "${merge(local.tags, map("kubernetes.io/cluster/${local.cluster_name}", "shared"))}"
}