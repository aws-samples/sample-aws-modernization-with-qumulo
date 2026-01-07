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
- `terraform destroy` to remove all compute resources, requires setting the term_protection flag to false in the terraform.tfvars file

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

---

## Workshop Summary

Congratulations on completing the **Cloud Native Qumulo on AWS Workshop**! Throughout this hands-on session, you've gained practical experience with enterprise-grade cloud storage solutions.

### What You've Learned

**1. Qumulo Architecture & Deployment**
- Deployed Cloud Native Qumulo using Terraform and Infrastructure as Code
- Configured persistent storage layer with S3 buckets
- Deployed compute infrastructure with Single-AZ and Multi-AZ configurations
- Understood the separation of compute and storage layers

**2. Qumulo Management & Operations**
- Navigated the Qumulo GUI and explored integrated analytics
- Configured multi-protocol access (NFS, SMB, S3)
- Managed file shares and export policies
- Monitored cluster performance and capacity trends

**3. Scalability & Elasticity**
- Converted Single-AZ cluster to Multi-AZ for high availability
- Scaled out by adding nodes to increase performance
- Scaled in by removing nodes to optimize costs
- Experienced zero-downtime cluster operations

**4. High Availability & Disaster Recovery**
- Created a secondary DR cluster for disaster recovery scenarios
- Implemented snapshot policies for point-in-time recovery
- Configured replication relationships between clusters
- Explored snapshot storage efficiency and recovery workflows

**5. Cloud Data Fabric (CDF)**
- Deployed hub-and-spoke architecture for global data access
- Configured portals for directory-level data sharing
- Experienced metadata-first data access with intelligent caching
- Understood bidirectional synchronization capabilities

### Key Takeaways

- **Cloud-Native Design**: Qumulo leverages AWS native services for scalability and resilience
- **Operational Flexibility**: Scale resources dynamically based on workload requirements
- **Data Protection**: Multiple layers of protection with snapshots and replication
- **Global Access**: Cloud Data Fabric enables seamless data access across locations
- **Cost Optimization**: Right-size infrastructure and clean up resources when not needed

### Next Steps

To continue your Qumulo journey:
- **Contact your AWS account team** for production deployment guidance
- **Explore Qumulo documentation** at [care.qumulo.com](https://care.qumulo.com)
- **Review AWS best practices** for storage and file system architectures
- **Consider hybrid workflows** combining on-premises and cloud deployments

---

Thank you for your time and participation in this workshop.  At this point you can close the AWS environment and end the workshop.  If you are interested in learning more about Cloud Native Qumulo on AWS, please reach out to your AWS account team for more information.
