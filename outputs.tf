#####
# Output
#####

output "ssh_user" {
  description = "SSH user to download kubeconfig file"
  value       = "ubuntu"
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
  value       = "/home/ubuntu/kubeconfig"
}

output "kubeconfig_ip" {
  description = "Path to the kubeconfig file using IP address"
  value       = "/home/ubuntu/kubeconfig_ip"
}

output "cloud_init_sh" {
  value = data.template_file.init_minikube.rendered 
}
