resource "aws_instance" "name" {
    ami = "ami-0f559c3642608c138"
    instance_type ="t3.micro"
     tags = {
        name="remotebackend"
    }
   
}

terraform {
  backend "s3" {
    bucket  = "venkatasaidevtopicsstf"
    key     = "dev/terraform.tfstate"
    region  = "ap-south-1"
    encrypt = true
  }
}