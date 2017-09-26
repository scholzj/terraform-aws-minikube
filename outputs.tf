#####
# Output
#####

output "ssh_user" {
    description = "SSH user to download kubeconfig file"
    value = "centos"
}

output "public_ip" {
    description = "Public IP address"
    value = "${aws_eip.minikube.public_ip}"
}

output "dns" {
    description = "Minikube DNS address"
    value = "${aws_route53_record.minikube.fqdn}"
}

output "kubeconfig_dns" {
    description = "Path to the the kubeconfig file using DNS address"
    value = "To copy the kubectl config file using DNS record, run: 'scp centos@${aws_route53_record.minikube.fqdn}:/home/centos/kubeconfig .'"
}

output "kubeconfig_ip" {
    description = "Path to the kubeconfig file using IP address"
    value = "To copy the kubectl config file using IP address, run: 'scp centos@${aws_eip.minikube.public_ip}:/home/centos/kubeconfig_ip .'"
}