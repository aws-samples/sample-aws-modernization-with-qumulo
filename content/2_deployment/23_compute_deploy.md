---
title: "Compute Storage Deployment"
chapter: true
weight: 23
---

## **Learning Objective**
By the end of this section, you will:
- Master the deployment of CNQ compute nodes that provide file system services, exploring both Single-AZ and Multi-AZ configurations while understanding how compute resources connect to the persistent storage layer to deliver scalable file services.

---

## **Overview**

Cloud Native Qumulo's **compute infrastructure deployment** creates the EC2 instances that provide your file system services. These compute nodes connect to the persistent storage layer you deployed earlier, forming a complete Qumulo cluster that delivers NFS, SMB, FTP, REST API and S3 access to your data.

The compute deployment demonstrates CNQ's flexible architecture - the same persistent storage can support different compute configurations, enabling you to scale or reconfigure compute resources without data migration.

## **Exploring the Compute Configuration**

### **Terraform Directory Structure**

Navigate to your compute deployment directory and examine the configuration:

```
cd /home/ssm-user/qumulo-workshop/terraform_deployment_primary_saz
ls -la
```

You'll see the compute infrastructure files alongside the persistent storage directory:

- **`terraform.tfvars`** - Contains all compute configuration values
- **`provider.tf`** - Defines providers and references persistent storage state
- **`main.tf`** - Contains compute resource definitions
- **`variables.tf`** - Defines input variables
- **`outputs.tf`** - Defines cluster information exports
- **`persistent-storage/`** - Directory containing your storage deployment

### **Examining Compute terraform.tfvars**

The compute `terraform.tfvars` file contains the specific configuration for your Qumulo cluster. Open this file to explore the key settings:

```
cat terraform.tfvars
```

**Key Configuration Parameters:**

**Deployment Identity**
- **`deployment_name`** - Unique identifier for the deployment

**S3 Utility Bucket Variables**
- **`s3_bucket_name`** - Utility bucket for Qumulo software
- **`s3_bucket_prefix`** - S3 prefix, if configured, where qumulo software tree resides
- **`s3_bucket_region`** - Region the utility bucket is configured in

**AWS Variables**
- **`aws_region`** - AWS region for compute resources
- **`aws_vpc_id`** - VPC where compute instances will be deployed
- **`ec2_key_pair`** - Preconfigured EC2 key pair in the region
- **`private_subnet_id`** - **Single subnet ID** for SAZ deployment
- **`term_protection`** - Set to false for workshop - true required for production

![compute tfvars configuration](/static/images/deployment/23_01.png)

**Qumulo Cluster Variables**
- **`q_cluster_name`** - Qumulo cluster identifier
- **`q_cluster_version`** - Qumulo software version
- **`q_cluster_admin_password`** - Administrative password

**Qumulo Cluster Config Options**
- **`q_persistent_storage_type`** - Storage backend type (default to hot_s3_int)
- **`q_instance_type`** - EC2 instance type (i4i.xlarge for workshop, not recommended for production)
- **`q_node_count`** - Number of cluster nodes (3, can be 1 or more)

![compute tfvars configuration cont.](/static/images/deployment/23_02.png)

::alert[**Single-AZ Deployment**: Notice that `private_subnet_id` contains only **one subnet ID**. This creates a Single-AZ cluster where all nodes are deployed in the same availability zone for this initial deployment.]

---

## **AWS Console: Exploring Created EC2 Instances**

After the compute deployment completes, EC2 instances are created to run your Qumulo cluster. Let's explore these in the AWS Console.

### **Accessing EC2 in the AWS Console**

1. **Open the AWS Console** in your browser
2. **Navigate to EC2** service
3. **View Running Instances**
4. **Filter by your deployment name** to see Qumulo instances

![AWS EC2 cluster compute instances](/static/images/deployment/23_03.png)

### **Understanding Instance Architecture**

Your Qumulo compute deployment creates **multiple EC2 instances**:

**Instance Configuration:**
- **Instance Type**: i4i.xlarge (4 vCPUs, 32 GB RAM, NVMe SSD storage)
- **Instance Count**: 3 nodes for high availability
- **Availability Zone**: All instances in **same AZ** (Single-AZ deployment)
- **Security Groups**: Pre-configured for Qumulo cluster communication

![AWS EC2 cluster compute availability zone placement](/static/images/deployment/23_04.png)

### **Single-AZ Deployment Characteristics**

**Key Observations:**

- **Availability Zone**: All 3 instances deployed in the **same AZ** (e.g., us-east-1a)
- **Subnet Placement**: All instances in the same private subnet
- **Performance**: Lower latency between nodes due to same-AZ placement
- **Cost**: Marginally more cost-effective than Multi-AZ deployment
- **Availability**: Single point of failure at AZ level
- **Workload Colocation**: Workloads should also live in the same AZ as the Qumulo cluster

::alert[**Single-AZ Limitation**: While cost-effective and performant, Single-AZ deployments are vulnerable to availability zone outages. This workshop will later demonstrate converting to Multi-AZ for higher availability.]{type="warning"}

---

## **Understanding Floating IP Addresses**

One of Qumulo's key features is **floating IP addresses** that provide seamless client connectivity and load distribution across cluster nodes.  Floating IP addresses can be added and removed depending on your specific cluster node count.  Single node clusters do not deploy floating IP addresses.  

::alert[**Workshop Insight**: Floating IPs enable Qumulo to provide consistent client access even as the cluster scales or nodes are replaced in Single AZ Deployments. Clients connect to floating IPs, not directly to instance IPs.  In a Multi AZ deployment Qumulo leverages Network Load Balancers for dynamic cluster access and traffic distribution.]

### **What are Floating IPs?**

Floating IP addresses are **virtual IP addresses** that:
- **Move between cluster nodes** automatically for load balancing
- **Provide consistent access points** for NFS and SMB clients
- **Enable seamless failover** if a node becomes unavailable
- **Distribute client connections** across the cluster

### **Viewing Floating IPs in Terraform Output**

Check your cluster's floating IP configuration:

```
cd /home/ssm-user/qumulo-workshop/terraform_deployment_primary_saz
terraform output
```

![compute floating and primary ip addresses](/static/images/deployment/23_05.png)

Floating IP addresses assigned to individual compute instances can be seen in the instance information in the AWS console:

![compute floating ip address details](/static/images/deployment/23_06.png)

Floating IP addresses are utilized with round robin DNS or internal Qumulo Authoritative DNS (QDNS).  
https://docs.qumulo.com/administrator-guide/network-configuration/configuring-authoritative-dns.html
For the purposes of this workshop we are utilizing round robin DNS in a private hosted Route53 zone file.  

![round robin dns settings in Route53](/static/images/deployment/23_11.png)

### **Key IP Address Types**

**Primary Node IPs:**
- **Static IP addresses** assigned to each EC2 instance
- **Can be used for cluster management** and inter-node communication
- **Direct access** to specific nodes for administration

**Floating IP Addresses:**
- **Virtual IPs** that float between nodes
- **Client access points** for file sharing protocols
- **Load balancing** across available nodes
- **Automatic failover** capabilities
- **Can be used for cluster management**

### **SSM Parameters: IP Address Mapping**

The deployment stores detailed IP address information in Systems Manager Parameter Store for reference:

```
# View cluster IP information from parameter store
aws ssm get-parameters --names $(aws ssm describe-parameters --parameter-filters Key=Name,Values="/qumulo/qum-wks-cls-pri",Option=Contains --query "Parameters[?contains(Name, 'float-ips') || contains(Name, 'node-ips')].Name" --output text)
```

![ssm parameter store CLI output](/static/images/deployment/23_07.png)

These can also be viewed in the AWS Console by navigating to Systems Manager, Parameter Store, and filtering for the cluster name: Name: contains: ```/qumulo/qum-wks-cls-pri```

![ssm parameter store console output](/static/images/deployment/23_08.png)

### **Understanding IP Address Distribution**

**Parameter Store Information:**
- **Primary IPs per Node** - Direct access to each cluster node
- **Floating IP Pool** - Available virtual IPs for client connections
- **IP-to-Node Mapping** - Which floating IPs are currently on which nodes
- **Subnet Information** - Network placement details

::alert[**Workshop Insight**: Floating IPs enable Qumulo to provide consistent client access even as the cluster scales or nodes are replaced. Clients connect to floating IPs, not directly to instance IPs.]

---

## **Cluster Connectivity Verification**

### **Accessing Your Qumulo Cluster**

With compute deployment complete, the next step is to verify cluster connectivity.  The workshop creates a text file containing all connectivity information for the clusters deployed.  As you progress through the workshop the content of this file will change:

**From the Linux Instance:**
```
# Check cluster access information
cat /home/ssm-user/qumulo-workshop/cluster-access-info.txt
```
![cluster access info text file](/static/images/deployment/23_09.png)

**From the Windows Instance:**
1. **RDP to Windows instance** using Fleet Manager
2. **Open browser** to the cluster web UI URL
3. **Login** with admin credentials from access info

![locate the windows instance connect button](/static/images/deployment/23_12.png)

![connect using RDP fleet manager](/static/images/deployment/23_13.png)

![log into windows instance](/static/images/deployment/23_14.png)

![Qumulo cluster login screen](/static/images/deployment/23_15.png)

---

## **Compute Deployment Architecture Summary**

### **What We've Deployed**

**Infrastructure Components:**
- **3 EC2 instances** (i4i.xlarge) in Single-AZ configuration
- **Floating IP pool** for client load balancing
- **Security groups** for cluster and client communication
- **Integration** with persistent S3 storage backend

**Qumulo Cluster Features:**
- **File system services** (NFS, SMB, REST API)
- **Web-based management** interface
- **Automatic load balancing** via floating IPs
- **High availability** within the availability zone

### **Next Steps**

With your Single-AZ cluster deployed and verified, you're ready to:

- **Explore cluster management** through the web interface
- **Test file system access** via NFS and SMB
- **Understand performance characteristics** of Single-AZ deployment
- **Prepare for Multi-AZ conversion** to enhance availability

The compute infrastructure now provides a fully functional Qumulo cluster, demonstrating how CNQ separates storage durability (S3) from compute services (EC2) while delivering enterprise file system capabilities.

::alert[**Workshop Advantage**: This Single-AZ deployment provides the foundation for understanding Qumulo's architecture before exploring Multi-AZ configurations that provide higher availability across multiple data centers.]