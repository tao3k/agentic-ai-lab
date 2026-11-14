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
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["10.0.0.1/16"]
  }
}
