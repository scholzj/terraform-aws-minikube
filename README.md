# AWS Minikube Terraform module

AWS Minikube is a single node Kubernetes deployment in AWS. It creates EC2 host and deploys Kubernetes cluster using [Kubeadm](https://kubernetes.io/docs/admin/kubeadm/) tool. It provides full integration with AWS. It is able to handle ELB load balancers, EBS disks, Route53 domains etc.

<!-- TOC depthFrom:2 -->

- [Updates](#updates)
- [Prerequisites and dependencies](#prerequisites-and-dependencies)
- [Including the module](#including-the-module)
- [Using custom AMI Image](#using-custom-ami-image)
- [Addons](#addons)
- [Custom addons](#custom-addons)
- [Tagging](#tagging)

<!-- /TOC -->

## Updates

* *23.6.2018:* Update to Kubernetes 1.10.5
* *8.6.2018:* Update to Kubernetes 1.10.4
* *27.5.2018:* Update to Kubernetes 1.10.3
* *28.4.2018:* Update to Kubernetes 1.10.2, make AMI image configurable
* *24.3.2018:* Update to Kubernetes 1.10.1
* *31.3.2018:* Update to Kubernetes 1.10.0, update Calico networking and update Kubernetes Dahsboard, Ingress and Heapster addons
* *24.3.2018:* Update to Kubernetes 1.9.6
* *17.3.2018:* Update to Kubernetes 1.9.4
* *10.2.2018:* Update to Kubernetes 1.9.3
* *22.1.2018:* Update Calico to 3.0.1
* *22.1.2018:* Update to Kubernetes 1.9.2, Ingres 0.10.0 and Dashboard 1.8.2
* *6.1.2018:* Update to Kubernetes 1.9.1
* *16.12.2017:* Update to Kubernetes 1.9.0, Update Dashboard, Ingress and Heapster dependencies
* *8.12.2017:* Update to Kubernetes 1.8.5
* *1.12.2017:* Fix problems with incorrect Ingress RBAC rights
* *28.11.2017:* Update addons (Heapster, Ingress, Dashboard, External DNS)
* *23.11.2017:* Update to Kubernetes 1.8.4
* *9.11.2017:* Update to Kubernetes 1.8.3
* *4.11.2017:* Update to Kubernetes 1.8.2
* *14.10.2017:* Update to Kubernetes 1.8.1
* *6.10.2017:* Make the storage class default storage class
* *29.9.2017:* Update to Kubernetes 1.8
* *28.9.2017:* Updated addon versions
* *26.9.2017:* Split into module and configuration
* *23.9.2017:* Bootstrap cluster purely through cloud init to skip AWS S3
* *18.9.2017:* Clarify the requirements for AWS infrastructure
* *11.9.2017:* Make it possible to connect to the cluster through the Elastic IP address instead of DNS name
* *2.9.2017:* Update to Kubeadm and Kubernetes 1.7.5
* *22.8.2017:* Update to Kubeadm and Kubernetes 1.7.4

## Prerequisites and dependencies

* AWS Minikube deployes into existing VPC / public subnet. If you don't have your VPC / subnet yet, you can use [this](https://github.com/scholzj/aws-vpc) configuration or [this](https://github.com/scholzj/terraform-aws-vpc) module to create one.
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

## Using custom AMI Image

AWS Minikube is built and tested on CentOS 7. But gives you the possibility to use their own AMI images. Your custom AMI image should be based on RPM distribution and should be similar to Cent OS 7. When `ami_image_id` variable is not specified, the latest available CentOS 7 image will be used.

## Addons

Currently, following addons are supported:
* Kubernetes dashboard
* Heapster for resource monitoring
* Storage class for automatic provisioning of persisitent volumes
* External DNS (Replaces Route53 mapper)
* Ingress

The addons will be installed automatically based on the Terraform variables. 

## Custom addons

Custom addons can be added if needed. Fro every URL in the `addons` list, the initialization scripts will automatically call `kubectl -f apply <Addon URL>` to deploy it. Minikube is using RBAC. So the custom addons have to be *RBAC ready*.

## Tagging

If you need to tag resources created by your Kubernetes cluster (EBS volumes, ELB load balancers etc.) check [this AWS Lambda function which can do the tagging](https://github.com/scholzj/aws-kubernetes-tagging-lambda).
