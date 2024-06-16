# AWS Minikube Terraform module

AWS Minikube is a single node Kubernetes deployment in AWS. It creates EC2 host and deploys Kubernetes cluster using [Kubeadm](https://kubernetes.io/docs/admin/kubeadm/) tool. It provides full integration with AWS. It is able to handle ELB load balancers, EBS disks, Route53 domains etc.

<!-- TOC depthFrom:2 -->

- [Updates](#updates)
- [Prerequisites and dependencies](#prerequisites-and-dependencies)
- [Including the module](#including-the-module)
- [Using custom AMI Image](#using-custom-ami-image)
- [Add-ons](#add-ons)
- [Custom add-ons](#custom-add-ons)
- [Tagging](#tagging)
- [Kubernetes version](#kubernetes-version)

<!-- /TOC -->

## Updates

* *16.6.2024* Update to Kubernetes 1.30.2
* *19.5.2024* Update to Kubernetes 1.30.1 + Ingress and External DNS add-on updates
* *29.4.2024* Update to Kubernetes 1.30.0
* *31.3.2024* Update to Kubernetes 1.29.3 + Ingress and External DNS add-on updates
* *18.2.2024* Update to Kubernetes 1.29.2 + Ingress add-on update
* *30.12.2023* Update to Kubernetes 1.29.0
* *26.11.2023* Update to Kubernetes 1.28.4
* *12.11.2023* Update to Kubernetes 1.28.3 + Update some add-ons
* *15.10.2023* Update to Kubernetes 1.28.2 + Update some add-ons
* *16.4.2023* Update to Kubernetes 1.27.1 + Use external AWS Cloud Provider
* *1.4.2023* Update to Kubernetes 1.26.3 + update add-ons (Ingress-NGINX Controller, External DNS, Metrics Server, AWS EBS CSI Driver)
* *4.3.2023* Update to Kubernetes 1.26.2 + update add-ons (Ingress-NGINX Controller)
* *22.1.2023* Update to Kubernetes 1.26.1 + update add-ons (External DNS)
* *10.12.2022* Update to Kubernetes 1.26.0 + update add-ons (AWS EBS CSI Driver, Metrics server)
* *13.11.2022* Update to Kubernetes 1.25.4 + update add-ons
* *2.10.2022* Update to Kubernetes 1.25.2 + update add-ons
* *26.8.2022* Update to Kubernetes 1.25.0 + Calico upgrade

## Prerequisites and dependencies

* AWS Minikube deploys into existing VPC / public subnet. If you don't have your VPC / subnet yet, you can use [this](https://github.com/scholzj/aws-vpc) configuration or [this](https://github.com/scholzj/terraform-aws-vpc) module to create one.
  * The VPC / subnet should be properly linked with Internet Gateway (IGW) and should have DNS and DHCP enabled.
  * Hosted DNS zone configured in Route53 (in case the zone is private you have to use IP address to copy `kubeconfig` and access the cluster).
* To deploy AWS Minikube there are no other dependencies apart from [Terraform](https://www.terraform.io). Kubeadm is used only on the EC2 host and doesn't have to be installed locally.

## Including the module

Although it can be run on its own, the main value is that it can be included into another Terraform configuration.

```hcl
module "minikube" {
  source = "github.com/scholzj/terraform-aws-minikube"

  aws_region    = "eu-central-1"
  cluster_name  = "my-minikube"
  aws_instance_type = "t2.medium"
  ssh_public_key = "~/.ssh/id_rsa.pub"
  aws_subnet_id = "subnet-8a3517f8"
  ami_image_id = "ami-b81dbfc5"
  hosted_zone = "my-domain.com"
  hosted_zone_private = false

  tags = {
    Application = "Minikube"
  }

  addons = [
    "https://raw.githubusercontent.com/scholzj/terraform-aws-minikube/master/addons/storage-class.yaml",
    "https://raw.githubusercontent.com/scholzj/terraform-aws-minikube/master/addons/heapster.yaml",
    "https://raw.githubusercontent.com/scholzj/terraform-aws-minikube/master/addons/dashboard.yaml",
    "https://raw.githubusercontent.com/scholzj/terraform-aws-minikube/master/addons/external-dns.yaml"
  ]
}
```

An example of how to include this can be found in the [examples](examples/) dir. 

## Using custom AMI Image

AWS Minikube is built and tested on CentOS 7. But gives you the possibility to use their own AMI images. Your custom AMI image should be based on RPM distribution and should be similar to Cent OS 7. When `ami_image_id` variable is not specified, the latest available CentOS 7 image will be used.

## Add-ons

Currently, following add-ons are supported:
* Kubernetes dashboard
* Heapster for resource monitoring
* Storage class and CSI driver for automatic provisioning of persistent volumes
* External DNS (Replaces Route53 mapper)
* Ingress

The add-ons will be installed automatically based on the Terraform variables. 

## Custom add-ons

Custom add-ons can be added if needed. Fro every URL in the `addons` list, the initialization scripts will automatically call `kubectl -f apply <Addon URL>` to deploy it. Minikube is using RBAC. So the custom add-ons have to be *RBAC ready*.

## Tagging

If you need to tag resources created by your Kubernetes cluster (EBS volumes, ELB load balancers etc.) check [this AWS Lambda function which can do the tagging](https://github.com/scholzj/aws-kubernetes-tagging-lambda).

## Kubernetes version

The intent for this module is to use it for development and testing against the latest version of Kubernetes. As such, the primary goal for this module is to ensure it works with whatever is the latest version of Kubernetes supported by Minikube. This includes provisioning the cluster as well as setting up networking and any of the [supported add-ons](#add-ons). This module might, but is not guaranteed to, also work with other versions of Kubernetes. At your own discretion, you can use the `kubernetes_version` variable to specify a different version of Kubernetes for the Minikube cluster.