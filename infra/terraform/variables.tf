variable "aws_region" {
  description = "AWS region (LocalStack)"
  type        = string
  default     = "ap-southeast-1"
}

variable "localstack_endpoint" {
  description = "LocalStack endpoint reachable from the Jenkins network"
  type        = string
  default     = "http://localstack:4566"
}

variable "ami_id" {
  description = "AMI for the app instance (LocalStack's built-in Amazon Linux image id)"
  type        = string
  default     = "ami-df5de72bdb3b"
}

variable "allowed_cidr" {
  description = "Internal network allowed to reach the app"
  type        = string
  default     = "10.0.0.0/8"
}

variable "docker_network" {
  description = "Docker network the host container joins (same network as Jenkins agents)"
  type        = string
  default     = "jenkins"
}
