#####
# Output
#####

output "ssh_user" {
  description = "SSH user to download kubeconfig file"
  value       = "ec2-user"
}

output "public_ip" {
  description = "Public IP address"
  value       = aws_eip.minikube.public_ip
}

output "dns" {
  description = "Minikube DNS address"
  value       = aws_route53_record.minikube.fqdn
}

output "kubeconfig_dns" {
  description = "Path to the the kubeconfig file using DNS address"
  value       = "/home/ec2-user/kubeconfig"
}

output "kubeconfig_ip" {
  description = "Path to the kubeconfig file using IP address"
  value       = "/home/ec2-user/kubeconfig_ip"
}

