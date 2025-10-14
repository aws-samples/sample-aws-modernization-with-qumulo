---
title: "Single-AZ to Multi-AZ (Cluster Replace)"
weight: 41
---

## **Overview of Cluster Replace Process**

The cluster replace process is a **critical scaling operation** that allows you to upgrade your existing Qumulo deployment while preserving all data and maintaining service availability. This process is essential for several scenarios:

- **Converting from Single-AZ to Multi-AZ deployment** for improved fault tolerance
- **Changing AWS instance types** to optimize performance or cost
- **Upgrading cluster configurations** that require complete recreation

### **Why Cluster Replace is Required**

Traditional scaling methods (stopping instances and changing types) would cause **multiple quorum events per node**, which can:
- Disrupt service availability
- Cause read/write cache optimization issues
- Create unnecessary downtime

The cluster replace methodology ensures a **two-quorum event process** that minimizes availability interruptions by:
1. **Creating a new deployment** in a separate Terraform workspace
2. **Joining new instances** to the existing quorum with current data
3. **Removing old instances** after the new cluster is fully operational
4. **Cleaning up resources** to maintain optimal configuration

### **Pre-Deployment Considerations**

Before initiating the cluster replace process it is important to consider your organization's change management proceedures:
- **Backup critical data** as a precautionary measure
- **Schedule during maintenance windows** to minimize impact
- **Verify network connectivity** between availability zones for Multi-AZ deployments
- **Confirm adequate resources** in target availability zones

---

## **Step 1: Prepare Multi-AZ Configuration**

### **Script Execution**

Execute the preparation script to generate the Multi-AZ configuration:

```
cd /home/ssm-user/qumulo-workshop/scripts
./primary-qumulo-cluster-saz-to-maz.sh
```

**⏱️ Estimated Time: Instant (< 30 seconds)**

### **What This Script Does**

The preparation script performs several key functions:
- **Generates Multi-AZ Terraform configuration** based on the original SingleAZ terraform deployment with proper zone distribution
- **Updates instance types** if specified in the configuration.  We are not only converting from Single-AZ to Multi-AZ, but also changing the instnace types from i4i instance generation and going to i7i instance generation.  The i7i instances give a ~20% performance improvement.
- **Creates deployment directory structure** for the new cluster
- **Validates network prerequisites** for Multi-AZ deployment

![maz configuration detail](../images/elasticity/41_01.png)

### **Expected Output Analysis**

The script output will display:
- **Configuration validation** confirming Multi-AZ parameters
- **Instance type updates** if being changed during the process
- **Deployment directory creation** showing the new workspace path
- **Network configuration** for cross-AZ communication (specifically a Multi-AZ cluster will deploy an AWS Network Load Balancer replacing the floating IP functionality)

We can explore the newly created terraform workspace by this script:

```
cd /home/ssm-user/qumulo-workshop/terraform_deployment_primary_maz
cat terraform.tfvars
```

You will notice the original cluster var file has been copied over and we've updated the following items:
- **private_subnet_id** updated from a single subnet (denoting SingleAZ deployment) to 3 subnet IDs (denoting MultiAZ deployment)
- **q_instance_type** updated to i7i.xlarge from i4i.xlarge which will replace the cluster with larger nodes (note you could also add additional nodes, but be aware MAZ cluster are 3 nodes or 5 or more nodes - you can't specify 4 or less than 3.)
- **q_replacement_cluster** set to true to initiate a cluster replace operation
- **q_existing_deployment_unique_name** set to the SingleAZ cluster unique deployment name

![maz tfvars 1](../images/elasticity/41_03.png)
![maz tfvars 2](../images/elasticity/41_04.png)

---

## **Step 2: Execute Cluster Replace Operation**

### **Script Execution**

Now execute the cluster replace operation:

```
cd /home/ssm-user/qumulo-workshop/scripts
./cluster-replace.sh "/home/ssm-user/qumulo-workshop/terraform_deployment_primary_maz" "Multi-AZ replacement cluster with NLB"
```

**⏱️ Estimated Time: 8-12 minutes**

#### **Successful Deployment**

### **Cluster Replace Process Phases**

The cluster replace operation follows these phases:

#### **Phase 1: New Deployment Creation (2-3 minutes)**
- **Creates new Terraform workspace** to isolate the replacement deployment
- **Initializes Terraform environment** with Multi-AZ configuration
- **Provisions new EC2 instances** across multiple availability zones
- **Sets up Network Load Balancer** for Multi-AZ distribution

#### **Phase 2: Quorum Formation (3-4 minutes)**
- **Joins new instances** to the existing cluster quorum
- **Synchronizes cluster state** across all nodes
- **Validates data integrity** during the transition
- **Establishes cross-AZ communication** links

#### **Phase 3: Service Migration (2-3 minutes)**
- **Transfers floating IP addresses** to the new cluster
- **Updates DNS configurations** for seamless client connectivity
- **Migrates active connections** to the new Multi-AZ infrastructure
- **Validates service availability** across all zones

#### **Phase 4: Cleanup (1-2 minutes)**
- **Removes old Single-AZ instances** from the quorum
- **Destroys legacy infrastructure** to prevent resource conflicts
- **Updates S3 bucket policies** for least privilege access
- **Finalizes configuration** for the new Multi-AZ cluster

![maz cluster replace success](../images/elasticity/41_07.png)

### **Key Monitoring Points**

During execution, monitor for:
- **Terraform apply confirmations** at each phase
- **Quorum formation messages** indicating successful node joining
- **IP address migration** showing floating IP transitions
- **Service health checks** confirming cluster availability

---

## **Step 2.5: Understanding the Cluster Replace Finalization**

### **Automated Infrastructure Cleanup**

The cluster replace script automatically handles the **final cleanup phase** of the cluster replacement process. After the new Multi-AZ cluster is successfully deployed and validated, the script performs additional terraform operations to remove the old Single-AZ infrastructure.

**⏱️ Automated Process: 2-3 minutes (no user action required)**

### **What the Script Does Automatically**

During the cluster replace operation, the script performs these additional steps:

#### **Terraform Configuration Update**
- **Modifies the terraform.tfvars file** to set `q_replacement_cluster = false`
- **Signals completion** of the cluster replacement process
- **Prepares for old infrastructure removal**

#### **Final Infrastructure Cleanup**
- **Executes additional terraform apply** to destroy old Single-AZ resources
- **Removes legacy EC2 instances** from the previous cluster
- **Cleans up security groups** and network configurations
- **Finalizes the Multi-AZ deployment** as the active cluster

### **Examining the Configuration Change**

Let's examine the terraform configuration file to understand what changed during the automated process:

```
cd /home/ssm-user/qumulo-workshop/terraform_deployment_primary_maz
cat terraform.tfvars
```

![maz cluster replace success](../images/elasticity/41_15.png)

### **Understanding the Replacement Cluster Variable**

The `q_replacement_cluster` variable serves as a **state flag** for the cluster replace process:

- **`q_replacement_cluster = true`** - Indicates this is a replacement deployment during active cluster replace
- **`q_replacement_cluster = false`** - Indicates cluster replace is complete and old infrastructure should be removed

#### **Why This Two-Phase Process is Necessary**

The two-phase approach ensures:
- **Data integrity** during the replacement process
- **Service availability** while new cluster is being validated
- **Clean resource management** without conflicting infrastructure
- **Proper state management** for terraform operations

### **Verification of Cleanup Completion**

After the automated cleanup completes, you can verify the process worked correctly:

#### **AWS Console Verification**
- **Old EC2 instances** are terminated and no longer appear in the console
- **Legacy security groups** have been removed
- **Only Multi-AZ infrastructure** remains active

#### **Terraform State Verification**

```
cd /home/ssm-user/qumulo-workshop/terraform_deployment_primary_maz
terraform state list
```

This command will show only the resources for the new Multi-AZ cluster, confirming the old infrastructure has been properly removed.

{{% notice info %}}
**Automated Process**: The cluster replace script handles all terraform configuration updates and cleanup automatically. Participants observe the process but don't need to manually execute these steps like you would in production.
{{% /notice %}}

{{% notice tip %}}
**Understanding Note**: The `q_replacement_cluster` variable is a safety mechanism that prevents accidental destruction of infrastructure during the cluster replace process. Only after successful deployment does the script set it to false and trigger cleanup.
{{% /notice %}}

---

## **Step 3: Monitor Cluster Replace Progress**

### **GUI Monitoring Tasks**

**⏱️ Estimated Monitoring Time: 10 minutes**

Access the Qumulo GUI and monitor the following during the cluster replace operation:

#### **Cluster Overview Dashboard**
- **Node status transitions** as new Multi-AZ nodes join you will notice under Client Activity on the main dashboard your node names will change from Node 1 - 3 to Node 4 - 6:
![GUI node additions](../images/elasticity/41_11.png)
- **Capacity and performance metrics** updating in real-time.  You might notice decreased latencies and increased IOPs/Throughput from the load test instances taking advantage of the i7i infrastructure.  
![GUI performance changes](../images/elasticity/41_06.png)
- **Availability zone distribution** showing the new Multi-AZ topology and updated instance types can be seen in the AWS EC2 console:
![multiaz instances](../images/elasticity/41_12.png)
- **Service health indicators** confirming operational status can be checked from the Cluster Overview section of the GUI
![cluster health](../images/elasticity/41_13.png)
#### **Network Configuration**
- **Floating IP address removal** examining the terraform output will show that the floating IPs were removed in favor of a network load balancer configuration:
```
cd /home/ssm-user/qumulo-workshop/terraform_deployment_primary_maz/
terraform output
```
![cluster health](../images/elasticity/41_10.png)

You can also see the floating IPs are no longer in the network configuration from the Cluster Network page in the GUI:
![GUI floating IPs](../images/elasticity/41_14.png)
- **DNS resolution** confirming proper client access paths.  Our script automatically updates the demopri.qumulo.local record in DNS to be a CNAME to the NLB hostname replacing the round robin A record.  This enables clients to continue to use the same DNS name to access the storage:
![route53 host record update](../images/elasticity/41_09.png)

### **Validation Checkpoints**

After the cluster replace completes, verify:

- **✅ All nodes are active** and distributed across multiple availability zones
- **✅ Floating IP addresses** are properly assigned to the new cluster
- **✅ Client connectivity** is maintained without interruption
- **✅ Data integrity** is preserved across the migration
- **✅ Performance metrics** meet or exceed previous baselines

---

## **Post-Replacement Considerations**

### **Operational Updates**

After successful cluster replace:
- **Update monitoring systems** to reflect new Multi-AZ infrastructure
- **Verify backup procedures** are compatible with Multi-AZ configuration
- **Test failover scenarios** to validate cross-AZ redundancy
- **Update documentation** with new cluster endpoints and configuration

### **Performance Optimization**

The new Multi-AZ cluster may require:
- **Cache warming** to achieve optimal performance levels
- **Load balancing tuning** for cross-AZ traffic distribution
- **Network optimization** for inter-AZ communication
- **Monitoring baseline establishment** for the new configuration

{{% notice info %}}
**Production Note**: The cluster replace process maintains data integrity and service availability, but because floating IPs are removed in favor of NLB configurations, hosts will need to resolve DNS names again.  Consider turning down TTL on DNS records before this type of operation. Be sure to plan accordingly for production deployments.
{{% /notice %}}

{{% notice tip %}}
**Performance Tip**: Multi-AZ deployments provide enhanced fault tolerance but may have slightly higher latency for cross-AZ operations. Monitor performance metrics to establish new baselines.  However true Multi-AZ applications may experience improved performance from having cluster nodes available in the AZ that they reside.  
{{% /notice %}}