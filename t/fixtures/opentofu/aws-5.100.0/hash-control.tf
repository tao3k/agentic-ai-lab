provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation     = true
}
resource "aws_iam_group_membership" "example" {
  name  = "example"
  group = "example"
  users = ["utIPHxYsX5E8zVX", "u3czpzvJxk89nnq", "alice", "alice"]
}
resource "aws_security_group" "example" {
  name = "example"
  vpc_id = "vpc-00000000"
  ingress {
    from_port = 443
    to_port = 443
    protocol = "6"
    security_groups = ["sg-a", "sg-a"]
    cidr_blocks = ["10.1.0.0/16", "10.0.0.0/16"]
  }
}
