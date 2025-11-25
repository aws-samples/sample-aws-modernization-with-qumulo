---
title: "Prerequisites" 
chapter: true
weight: 21
---

Before deploying Cloud Native Qumulo (CNQ) on AWS, you need to ensure that your AWS environment meets the essential infrastructure and permission requirements. This section covers the foundational prerequisites that enable successful CNQ deployment and operation.

## **Learning Objective**
By the end of this section, you will:
- Identify and validate the essential AWS infrastructure requirements, IAM permissions, and network configurations needed for successful CNQ deployment, including VPC setup, subnet planning, and security group configurations.

---

## **CNQ Deployment Methods**

Cloud Native Qumulo supports **two primary deployment methods** on AWS:

### **Terraform Deployment** *(Workshop Focus)*
- **Industry Standard**: Most customers prefer Terraform for infrastructure as code
- **Flexibility**: Enables version control, reusable modules, and automated deployments
- **Workshop Approach**: This workshop uses Terraform configurations for hands-on experience

### **CloudFormation Deployment** *(Alternative Method)*
- **AWS Native**: Leverages AWS's native infrastructure as code service
- **Integration**: Seamless integration with AWS services and console
- **Enterprise Use**: Popular for AWS-centric organizations

::alert[**Workshop Focus**: While CNQ supports both deployment methods, this workshop concentrates on **Terraform deployment** as it represents the most common customer implementation pattern. The pre-configured workshop environment includes ready-to-use Terraform configurations.]

---

## **Essential AWS Prerequisites**

### **AWS Account Requirements**
- **Active AWS Account** with appropriate billing setup
- **Administrative Permissions** for the deploying user/role
- **Service Limits** verified for EC2, VPC, and storage resources
- **Regional Support** in your target AWS region

### **Network Infrastructure**
- **VPC Configuration** with appropriate CIDR blocks
- **Subnet Planning** across multiple Availability Zones
- **Internet Gateway** for public subnet connectivity
- **NAT Gateway** for private subnet outbound internet access
- **Route Tables** properly configured for traffic 
- **S3 Gateway Endpoint** properly configured S3 gateway endpoint is required in the deployment VPC

### **Security Configuration**
- **Security Groups** with appropriate ingress/egress rules
- **IAM Roles and Policies** for CNQ servic operations
- **KMS Keys** for encryption (optional but recommended)
- **SSH Key Pairs** for instance access

### **Compute and Storage**
- **EC2 Instance Types** appropriate for your workload requirements
- **EBS Volume Types** and sizing for persistent storage
- **Instance Limits** sufficient for your planned cluster size

---

## **Workshop Environment**

### **Pre-Configured Infrastructure**
The workshop environment **automatically provisions** all prerequisite infrastructure:

- ✅ **VPC with Multi-AZ Subnets** - Complete network foundation
- ✅ **Security Groups** - Properly configured for CNQ communication
- ✅ **IAM Roles and Policies** - All necessary permissions pre-configured
- ✅ **SSH Key Management** - Automated key generation and distribution
- ✅ **Parameter Store Integration** - Infrastructure details readily accessible

### **What You'll Validate**
During the workshop, you'll:
- **Verify Network Connectivity** between subnets and availability zones
- **Confirm IAM Permissions** for Terraform and CNQ operations
- **Validate Security Group Rules** for cluster communication
- **Test SSH Access** to deployed instances

---

## **Detailed Documentation References**

For comprehensive prerequisite information and deployment guidance:

### **Terraform Deployment**
📖 **[Qumulo Terraform Documentation](https://docs.qumulo.com/cloud-native-aws-administrator-guide/getting-started/terraform.html)**
- Complete Terraform module documentation
- Advanced configuration options
- Production deployment best practices

### **CloudFormation Deployment**
📖 **[Qumulo CloudFormation Documentation](https://docs.qumulo.com/cloud-native-aws-administrator-guide/getting-started/cloudformation.html)**
- CloudFormation template reference
- Parameter configuration guide
- Stack deployment procedures

## **Connecting to the Workshop Linux Instance**

Throughout this workshop you will be using a pre-created Linux instance.  This instance serves as both the terraform configuration server and a platform to test and view NFS based workloads.  You should connect to the instance through AwS Session Manager.  This enables you to access the Linux environment through your browser without external access and managing SSH security keys.

### **Linux Instance Connection**
1. **Connect to Instance** using Session Manager
2. **Set the Bash Environment** to properly configure the user interface - required every time you connect to the instance through session manager  ```bash -l```

![locate the linux instance connect button](/static/images/deployment/21_01.png)

![connect using session manager](/static/images/deployment/21_02.png)

![set the bash shell environment](/static/images/deployment/21_03.png)

---

## **Next Steps**
With prerequisites understood, you're ready to explore the **pre-configured workshop infrastructure** that eliminates manual setup complexity while demonstrating real-world CNQ deployment patterns.

::alert[**Workshop Advantage**: The automated workshop environment handles all prerequisite setup, allowing you to focus on understanding CNQ architecture and deployment workflows rather than infrastructure configuration.]
