---
title: "Scale In - Removing Nodes"
weight: 43
---

## **Overview of Node Removal Process**

Node removal allows you to **optimize resource usage and reduce operational costs** by reducing cluster size when performance requirements decrease. This scale-in operation is essential for cost management and right-sizing your infrastructure based on actual workload requirements.

### **Two-Step Node Removal Process**

Removing nodes from an existing cluster is a **two-step process**:

1. **Remove the node from your cluster's quorum** - This must be performed while the cluster is running
2. **Tidy up the AWS resources** for the removed nodes using Terraform

For this workshop, we'll be removing **2 nodes** to demonstrate the scale-in process and show how to safely reduce cluster performance.

### **Key Benefits of Node Removal**

Node removal provides:
- **Cost optimization** through reduced EC2 instance infrastructure costs
- **Resource efficiency** by matching performance to actual demand
- **Simplified management** with fewer nodes to monitor and maintain
- **Maintained data integrity** throughout the removal process

### **Prerequisites for Node Removal**

Before removing nodes, ensure:
- **Cluster is running** and healthy
- **Sufficient performance** remains after node removal
- **Proper quorum** will be maintained after removal

---

## **Step 1: Execute Node Removal**

### **Script Execution**

Run the automated node removal script:

```
cd /home/ssm-user/qumulo-workshop/scripts
./remove-cluster-node.sh
```

**⏱️ Estimated Time: 10 minutes**

### **Node Removal Process Phases**

The node removal operation follows these phases:

#### **Phase 1: Quorum Preparation (2-3 minutes)**
- **Identifies nodes for removal** based on current cluster topology
- **Prepares cache data evacuation** from nodes marked for removal
- **Checks cluster health** before initiating removal process

#### **Phase 2: Cache Data Evacuation (4-5 minutes)**
- **Evacuates cache data** from nodes to be removed to persistent storage
- **Commits write cache contents** to the Object Storage layer
- **Maintains data integrity** during the evacuation process
- **Validates cache consistency** across remaining nodes

#### **Phase 3: Quorum Reconfiguration (2-3 minutes)**
- **Removes nodes from quorum** while cluster remains operational
- **Reconfigures floating IP addresses** for remaining nodes
- **Updates cluster topology** to reflect new node count
- **Validates new quorum** formation and stability

#### **Phase 4: Resource Cleanup (1-2 minutes)**
- **Updates Terraform configuration** to reflect reduced node count
- **Terminates EC2 instances** for removed nodes
- **Cleans up security groups** and network configurations
- **Finalizes infrastructure** state for the scaled-in cluster

![node remove script execution](/static/images/elasticity/43_04.png)

### **Expected Output Analysis**

The script output will display:
- **Current cluster status** showing nodes before removal
- **Cache data evacuation progress** with migration status
- **Quorum reconfiguration** confirmation messages
- **EC2 instance termination** for removed nodes
- **New cluster configuration** with reduced node count

### **Key Monitoring Points**

During execution, monitor for:
- **Cache data evacuation completion** ensuring all data is safely committed
- **Quorum formation** messages confirming stable cluster state
- **EC2 termination** confirmations for removed instances
- **Performance stability** throughout the removal process

---

## **Step 1.5: Understanding the Terraform Process**

### **Two-Phase Terraform Operation**

The node removal script executes a **two-phase terraform process** to safely remove nodes from the cluster. While the script runs these phases automatically, understanding the underlying terraform operations provides insight into the removal process.

**⏱️ Automated Process: Part of the 10-minute total execution time**

### **Phase 1: Node Removal from Cluster**

#### **Terraform Configuration Changes**
The script first updates the terraform configuration to initiate node removal, this will not be visible after the node removal because our script performs the second step, but the initial configuration would look like the following:

```
# View the current terraform configuration
cd /home/ssm-user/qumulo-workshop/terraform_deployment_primary_maz
cat terraform.tfvars | grep -E "q_node_count|q_target_node_count"
```

**Before Node Removal:**

- q_node_count = 5
- q_target_node_count = null


**After Phase 1 Configuration Update:**

- q_node_count = 5
- q_target_node_count = 3


#### **What `q_target_node_count` Does**
- **Signals cluster reduction** from current node count to target count
- **Initiates cache data evacuation** from nodes marked for removal
- **Maintains cluster quorum** during the removal process
- **Preserves data integrity** throughout the operation

![phase 1 tfvars](/static/images/elasticity/43_05.png)

#### **Phase 1 Terraform Operations**

This terraform apply performs:
- **Removes nodes from cluster quorum** (reduces from 5 to 3 nodes)
- **Evacuates cache data** from nodes being removed to persistent storage
- **Maintains EC2 instances** for removed nodes (they remain running but are not part of the cluster)
- **Updates cluster topology** to reflect new node count

### **Phase 2: Infrastructure Cleanup**

#### **Terraform Configuration Finalization**
After successful node removal from the cluster, the script updates the configuration again:

**After Phase 2 Configuration Update:**

- q_node_count = 3
- q_target_node_count = null

```
# View the current terraform configuration
cd /home/ssm-user/qumulo-workshop/terraform_deployment_primary_maz
cat terraform.tfvars | grep -E "q_node_count|q_target_node_count"
```

#### **What These Changes Accomplish**
- **`q_node_count = 3`** - Updates the desired cluster size to match the new reality
- **`q_target_node_count = null`** - Signals that the node removal process is complete
- **Triggers infrastructure cleanup** for the removed nodes

![phase 2 tfvars](/static/images/elasticity/43_06.png)

#### **Phase 2 Terraform Operations**

This final terraform apply performs:
- **Terminates EC2 instances** for the 2 removed nodes
- **Cleans up security groups** and network configurations
- **Removes storage attachments** for destroyed instances
- **Updates infrastructure state** to reflect the final 3-node cluster

### **Cache Data vs. Persistent Storage**

#### **Important Distinction**
Unlike traditional storage systems, **Qumulo Cloud Native does not rebalance persistent storage** during node removal because:

- **Persistent data** lives on the **Object Storage layer** (S3)
- **Node removal only affects** the **cache layer** on compute instances
- **Cache data evacuation** commits write cache contents to persistent storage
- **Read cache data** is simply discarded (as it's cached copies of persistent data)

#### **What Gets Moved During Node Removal**
- **✅ Cache data** - Write cache contents committed to persistent storage
- **✅ Cache metadata** - Cache state information preserved
- **❌ Persistent storage** - Remains unchanged on Object Storage layer
- **❌ File system data** - No data migration required

### **Monitoring the Two-Phase Process**

During script execution, you can observe both phases:

#### **Phase 1 Indicators**
- **Cluster quorum changes** showing node count reduction
- **Cache evacuation progress** in the Qumulo GUI
- **Nodes marked for removal** still visible but inactive

#### **Phase 2 Indicators**
- **EC2 instance termination** in AWS console
- **Infrastructure cleanup** messages in terraform output
- **Final cluster state** with updated node count

::alert[**Automated Process**: While the script handles both terraform phases automatically, understanding this two-phase approach helps explain why node removal takes longer than node addition - the cache evacuation process ensures no data loss.]

::alert[**Technical Insight**: The `q_target_node_count` variable acts as a safety mechanism, ensuring cluster operations complete successfully before infrastructure cleanup begins.]

---

## **Step 2: Monitor Scale-In Process**

### **GUI Monitoring Tasks**

**⏱️ Estimated Monitoring Time: 10 minutes**

Access the Qumulo GUI and monitor the following during the node removal operation:

#### **Cluster Overview Dashboard**
- **Node count reduction** from current total to new reduced count
- **Capacity metrics** showing adjusted storage availability
- **Performance indicators** maintaining throughput levels
- **Health status** confirming operational stability

#### **Cache Data Migration Monitoring**
- **Cache data evacuation progress** from nodes being removed
- **Cache rebalancing** across remaining nodes
- **I/O performance** during cache evacuation
- **Completion status** of cache evacuation operations

#### **Quorum Status Validation**
- **Active node count** decreasing to target number
- **Quorum stability** throughout the removal process
- **Floating IP redistribution** among remaining nodes
- **Network connectivity** validation post-removal

Nodes before removal:

![nodes before removal](/static/images/elasticity/43_01.png)

Nodes after removal:

![nodes after removal](/static/images/elasticity/43_02.png)

### ** Performance and network Impact**

Monitor the following during scale-in:

#### **Storage Performance Changes**
- **Cache utilization** may increase on remaining nodes
- **Compute Utilization percentage** may increase on remaining nodes
- **Performance baseline** adjustment for reduced infrastructure

#### **Network Configuration Updates**
- **Floating IP addresses** redistributed among remaining nodes
- **Load balancing** adjusted for reduced node count
- **Client connectivity** maintained through IP redistribution
- **DNS resolution** updated for new cluster topology

![performance after removal](/static/images/elasticity/43_03.png)

---

## **Step 3: Validate Scale-In Success**

### **Post-Removal Verification**

After the node removal completes, verify the following:

#### **Cluster Health Checks**
- **✅ Remaining nodes active** and responsive in the cluster
- **✅ Node count** matches expected total (original - 2 removed)
- **✅ Data integrity** preserved throughout removal process
- **✅ Quorum stability** maintained with reduced node count
- **✅ Performance metrics** stable with new configuration

#### **Performance Validation**

- **✅ Cache distribution** balanced across remaining nodes
- **✅ Utilization levels** within acceptable ranges
- **✅ Performance baselines** established for new configuration
- **✅ Client connectivity** maintained through all endpoints

#### **Resource Cleanup Verification**
- **✅ EC2 instances** terminated for removed nodes
- **✅ Terraform state** updated to reflect new configuration
- **✅ Security groups** cleaned up for removed resources
- **✅ Network configurations** updated for reduced topology
- **✅ Monitoring systems** adjusted for new cluster size

### **Expected Reduction**

With 2 nodes removed:

- **Performance throughput** reduced by removed compute resources
- **Cache capacity** decreased but balanced across remaining nodes
- **Cost savings** achieved through reduced infrastructure usage

---

## **Operational Considerations**

### **Performance Impact**

After node removal:
- **Remaining nodes** may experience higher utilization
- **Cache rebalancing** occurs automatically in the background
- **Performance baselines** need to be re-established
- **Client connections** may experience brief reconnection

### **Cost Optimization**

Node removal reduces:
- **EC2 instance costs** for terminated nodes
- **Network transfer costs** with fewer nodes
- **Overall operational expenses** through optimized sizing


### **Future Scaling Considerations**

After scale-in:
- **Adding nodes** is straightforward if performance needs increase
- **Monitoring thresholds** should be adjusted for new baseline
- **Performance expectations** should align with reduced resources

::alert[**Data Safety**: The node removal process maintains data integrity through automated cache data evacuation before nodes are removed from the cluster. However, always verify cluster health after completion.]

::alert[**Cost Optimization**: Regular capacity planning and scale-in operations help maintain cost efficiency by matching infrastructure to actual performance demand while preserving the ability to scale back up when needed.]

::alert[**Performance Monitoring**: After node removal, establish new performance baselines and monitor cluster utilization to ensure optimal performance with the reduced infrastructure.]