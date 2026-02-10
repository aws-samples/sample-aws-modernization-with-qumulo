---
title: "Resource Cleanup"
chapter: true
weight: 10
---

In this final section, we will clean up all resources created during the workshop. This comprehensive cleanup process ensures that **all Qumulo clusters are destroyed** and **all persistent storage buckets are emptied and removed** through Terraform, preparing the infrastructure for complete termination when the workshop account is removed.

This cleanup process demonstrates several key benefits:
- **Cost optimization**: Ensures AWS does not incur any additional costs after the workshop
- **Infrastructure as Code**: Shows the ease of removing Qumulo clusters with `terraform destroy`
- **Complete resource management**: Removes both compute and storage layers systematically

## Cleanup Process Overview

The cleanup process follows a structured approach to ensure all resources are properly removed.  The automated cleanup script streamlines this process but in general to remove a qumulo cluster you follow these steps:

### Step 1: Compute Layer Removal
From the workshop Terraform directory, we execute:
- `update terraform.tfvars` and set term_protection = false
- `terraform init` to initialize the Terraform configuration
- `terraform apply` to enable terraform destroy command
- `terraform destroy` to remove all compute resources, requires setting the term_protection flag to false in the terraform.tfvars file.

### Step 2: Persistent Storage Removal
From the terraform persistent_storage directory, we execute:
- `update terraform.tfvars` and set prevent_destroy = false
- `terraform init` to initialize the persistent storage configuration
- `terraform apply` to enable persistent storage removal
- `terraform destroy` to remove all persistent storage buckets

This two-step process ensures **complete resource removal** for all clusters deployed by the workshop environment.

## Running the Cleanup

To execute the complete cleanup process, run the following command from your workshop environment:



::alert[**WARNING: This operation will DESTROY ALL CLUSTER RESOURCES and is NOT REVERSIBLE**: Execution of this script effectively renders the workshop environment unusable.]{type="warning"}



```
cd /home/ssm-user/qumulo-workshop/scripts
./cleanup-qumulo-environment.sh
```

![cleanup script](/static/images/cleanup/100_01.png)


The cleanup script will automatically handle both the compute and storage layer removal across all deployed clusters.

Thank you for your time and participation in this workshop.  At this point you can close the AWS environment and end the workshop.  If you are interested in learning more about Cloud Native Qumulo on AWS, please reach out to your AWS account team for more information.
