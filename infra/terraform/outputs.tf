output "instance_id" {
  description = "EC2 instance id (LocalStack)"
  value       = aws_instance.app.id
}

output "instance_private_ip" {
  description = "EC2 instance private IP (LocalStack)"
  value       = aws_instance.app.private_ip
}

output "security_group_id" {
  description = "Security group that opens port 8080"
  value       = aws_security_group.web.id
}

output "ansible_host" {
  description = "IP of the host container that Ansible configures"
  value       = docker_container.host.network_data[0].ip_address
}

output "ssh_private_key" {
  description = "Private key Ansible uses to log in to the host"
  value       = tls_private_key.ansible.private_key_openssh
  sensitive   = true
}
