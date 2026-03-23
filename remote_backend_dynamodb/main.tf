resource "aws_instance" "name" {
    ami = "ami-0f559c3642608c138"
    instance_type ="t3.micro"
     tags = {
        Name="remotebackend"
    }
}
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket-vs"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}