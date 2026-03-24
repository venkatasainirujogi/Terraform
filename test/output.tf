output "public_ip" {
  value = aws_instance.name.public_ip
}
output "private_ip" {
  value = aws_instance.name.private_ip
}
output "avaliblity_zone" {
    value = aws_instance.name.availability_zone
  
}