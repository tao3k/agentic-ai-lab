terraform {
  required_providers {
    aws = {
      source = "registry.terraform.io/hashicorp/aws"
      version = "= 5.100.0"
    }
  }
}
resource "aws_security_group" "example" {
  ingress {
    to_port = 443
    protocol = "tcp"
  }
}
