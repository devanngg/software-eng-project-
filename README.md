# EKS CI/CD with Terraform and Jenkins

This project provisions an Amazon EKS cluster in private subnets, deploys a small NGINX service, and provides a Jenkins pipeline for planning, applying, and destroying the infrastructure. The layout follows the architecture in the supplied diagram.

## Repository layout

```text
.
├── Jenkinsfile                         # Jenkins Multibranch Pipeline
├── LocalJenkinsfile                    # Jenkins pipeline for local kind
├── kind-config.yaml                    # Free local Kubernetes cluster
├── jenkins_server/
│   ├── scripts/install_build_tools.sh   # EC2 bootstrap script
│   └── tf-aws-ec2/                      # Jenkins host infrastructure
├── manifest/                            # Demo page, NGINX Deployment, Service, Namespace
└── tf-aws-eks/                          # VPC, private subnets, EKS cluster
```

## Free local alternative

If you do not want AWS charges, do not run `terraform apply` or the AWS
`Jenkinsfile`. Use Docker Desktop, kind, and kubectl instead. This runs the
same NGINX manifests locally and does not create EKS, EC2, NAT Gateway, or AWS
LoadBalancer resources.

Install the local tools on macOS:

```sh
brew install kind kubectl
```

Start Docker Desktop, then create and deploy the local cluster:

```sh
./scripts/local-kubernetes.sh up
```

Open the application in another terminal:

```sh
./scripts/local-kubernetes.sh port-forward
```

Then visit <http://localhost:8080>. Check the workload with:

```sh
kubectl get pods,service -n eks-nginx-app
```

The browser shows a project overview page served from a Kubernetes ConfigMap,
instead of the stock NGINX welcome screen. For a presentation, show that page,
the `kubectl get pods,service` output, and the architecture diagram at
`image.png` in VS Code.

Delete the local cluster when finished:

```sh
./scripts/local-kubernetes.sh down
```

For local Jenkins practice, use `LocalJenkinsfile` as the pipeline script.
It only requires Docker, kind, and kubectl and never uses AWS credentials.

## Before you start

You need an AWS account, AWS CLI, Terraform, kubectl, and a Jenkins installation with Pipeline support. For the Jenkins host, create an EC2 key pair and an S3 bucket for Terraform state. Enable S3 versioning and block public access on the state bucket. Use separate state keys for the Jenkins host and each EKS environment. The S3
backend is configured to use Terraform's S3 lock file support, so the Jenkins
identity must be allowed to read and write both the state object and its
`.tflock` object.

Use an IAM role / instance profile for Jenkins in AWS. Do not put AWS access keys in the `Jenkinsfile`, source code, or Git. The identity used by Jenkins needs the AWS permissions to manage the resources in the Terraform plan and access the EKS Kubernetes API. Grant only the permissions your account and chosen Terraform modules require.

The example `tf-aws-eks/variables/dev.tfvars` uses the documentation-only CIDR `203.0.113.10/32`; replace it with the public IPv4 CIDR from which the Kubernetes API should be reachable. The cluster API is public but CIDR-restricted. Include the Jenkins host’s stable outbound public IP (or NAT egress IP) and any operator IPs in the allowlist; the Jenkins and EKS stacks use separate VPCs. Worker nodes use private subnets. Set an EKS Kubernetes version available in your selected region before deployment.

## Create the Jenkins host

Pass your S3 bucket at init time (backend blocks cannot use Terraform variables):

```sh
cd jenkins_server/tf-aws-ec2
terraform init \
  -backend-config="bucket=YOUR_VERSIONED_STATE_BUCKET" \
  -backend-config="key=jenkins/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="encrypt=true"
terraform plan -var-file=variables/dev.tfvars
```

Before planning, edit `variables/dev.tfvars`: set `key_pair_name` to an existing EC2 key pair and set `admin_cidrs` to your own public IPv4 CIDR (the sample is documentation-only). Empty `admin_cidrs` leaves Jenkins and SSH unreachable. Review the security group, IAM permissions, and cost estimate for your environment. Then run `terraform apply` only after reviewing the plan.

## Configure the Jenkins pipeline

Create a Jenkins Multibranch Pipeline pointing at this repository so Jenkins checks out this `Jenkinsfile` and uses this workspace layout. Configure the Jenkins agent with Terraform, AWS CLI, kubectl, and an AWS instance profile/role. The Jenkins host stack expects an existing instance profile, specified in `variables/dev.tfvars`; give its role only the permissions needed for the selected infrastructure and deployment. Add no long-lived AWS credentials to Jenkins credential text fields.

The job asks for:

- `ACTION`: `plan`, `apply`, or `destroy`.
- `ENVIRONMENT`: `dev`, `test`, or `prod`. This selects the matching tfvars file and state key.
- `AWS_REGION`: region for the EKS stack.
- `TF_STATE_BUCKET`: existing versioned S3 bucket for remote state.

The EKS cluster names and state keys are environment-specific: `my-eks-cluster-dev` / `eks/dev/terraform.tfstate`, `my-eks-cluster-test` / `eks/test/terraform.tfstate`, and `my-eks-cluster-prod` / `eks/prod/terraform.tfstate`. Every run formats and validates Terraform and produces a plan. `apply` and `destroy` pause at an approval gate. `apply` deploys NGINX after the cluster is ready and waits for the deployment to become available. `destroy` removes the selected EKS stack; it does not destroy the separate Jenkins host.
The pipeline also runs a Trivy HIGH/CRITICAL configuration scan before planning. Ensure Trivy is installed on the Jenkins agent.

The EKS module grants cluster creator admin access to the identity that creates the cluster. Ensure the Jenkins AWS identity is the intended cluster creator, and configure access for other administrators separately using EKS access entries and least-privilege policies.

## Run Terraform locally

```sh
cd tf-aws-eks
terraform init \
  -backend-config="bucket=YOUR_VERSIONED_STATE_BUCKET" \
  -backend-config="key=eks/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="encrypt=true"
terraform validate
terraform plan -var-file=variables/dev.tfvars
```

Run the same checks used by Jenkins from the repository root:

```sh
terraform fmt -check -recursive
terraform -chdir=tf-aws-eks init -backend=false
terraform -chdir=tf-aws-eks validate
terraform -chdir=jenkins_server/tf-aws-ec2 init -backend=false
terraform -chdir=jenkins_server/tf-aws-ec2 validate
```

After reviewing the plan and checking the region, CIDR, instance type, version, and expected costs, apply explicitly:

```sh
terraform apply -var-file=variables/dev.tfvars
```

To deploy from your workstation after applying, use the same AWS identity that has EKS access:

```sh
aws eks update-kubeconfig --name my-eks-cluster-dev --region us-east-1
kubectl apply -f manifest/namespace.yaml
kubectl apply -n eks-nginx-app -f manifest/site.yaml -f manifest/deployment.yaml -f manifest/service.yaml
kubectl get pods,services -n eks-nginx-app
```

The service is `LoadBalancer`, so AWS will provision a public load balancer and incur charges. The example deployment uses two replicas, health probes, resource requests/limits, and a pinned NGINX image. Remove the cluster when you are finished:

```sh
cd tf-aws-eks
terraform destroy -var-file=variables/dev.tfvars
```

Delete the Jenkins host separately when no longer needed. Keep the S3 state bucket until both Terraform stacks have been destroyed and their state is no longer needed.

## Adaptation notes

This is an educational deployment scaffold. The upstream example included a fixed AWS account ID, a fixed key name, an old Kubernetes version, broad public ingress rules, and a pipeline that checked out a different repository and branch. Those assumptions have been removed from the EKS inputs and pipeline. Review the Jenkins host Terraform and installer before using them in an account: production Jenkins should use HTTPS, private networking or a VPN, restricted ingress, managed secrets, hardened agents, monitoring, and a tested backup/recovery process.
