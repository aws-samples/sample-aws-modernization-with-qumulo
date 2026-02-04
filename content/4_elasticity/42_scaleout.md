---
title: "Scale Out - Adding Nodes"
weight: 42
---

## **Overview of Node Addition Process**

The node addition process allows you to **increase storage performance** by adding additional compute resources to your existing Qumulo cluster. This horizontal scaling approach is essential for meeting growing storage demands and performance requirements in production environments.

### **Multi-AZ Node Requirements**

Multi-AZ deployments have specific node count requirements for optimal performance and fault tolerance:
- **Minimum 3 nodes** for basic Multi-AZ configuration
- **Scale to 5 or more nodes** for enhanced fault tolerance
- **Incompatible node counts** are 1, 2 or 4

For this workshop, we'll be adding **2 additional nodes** to demonstrate the scale-out process for Multi-AZ clusters.

### **Key Benefits of Node Addition**

Adding nodes to your cluster provides:
- **Enhanced performance** with more compute and cache resources
- **Improved fault tolerance** with greater node redundancy
- **Better workload distribution** across the expanded cluster

### **Prerequisites for Node Addition**

Before adding nodes, ensure:
- **Total node count** must be greater than current deployment
- **Network connectivity** validated for Multi-AZ communication
- **Adequate resources** in target availability zones

---

## **Step 1: Execute Node Addition**

:::alert[**Tip**: Open the Qumulo GUI dashboard now before running the script so you can monitor the node addition in real-time.]{type="info"}

### **Script Execution**

Run the automated node addition script:

```
cd /home/ssm-user/qumulo-workshop/scripts
./add-cluster-node.sh
```

**⏱️ Estimated Time: 6 minutes**

### **Node Addition Process Phases**

The node addition operation follows these phases:

#### **Phase 1: Terraform Configuration Update (1 minute)**
- **Updates terraform.tfvars** with new node count parameters (simply increasing q_node_count variable from 3 to 5 in this case)
- **Validates configuration** for Multi-AZ node distribution
- **Prepares deployment environment** for additional resources
- **Checks resource availability** in target availability zones

![node add tfvars](/static/images/elasticity/42_01.png)

#### **Phase 2: Infrastructure Provisioning (2-3 minutes)**
- **Launches new EC2 instances** across availability zones
- **Configures networking** for Multi-AZ communication
- **Sets up security groups** and access controls
- **Initializes storage attachments** for new nodes

#### **Phase 3: Cluster Integration (2-3 minutes)**
- **Joins new nodes** to existing cluster quorum
- **Synchronizes cluster state** across all nodes
- **Validates node health** and connectivity
- **Begins cache data rebalancing** across expanded cluster

![node add terraform output](/static/images/elasticity/42_05.png)

### **Expected Output Analysis**

The script output will display:
- **Terraform plan confirmation** showing resources to be added
- **Node provisioning progress** with EC2 instance creation
- **Cluster integration status** as nodes join the quorum
- **IP address assignments** for new nodes
- **Health check confirmations** validating successful integration

### **Key Monitoring Points**

During execution, monitor for:
- **Terraform apply success** for new node resources
- **EC2 instance launch** confirmations across availability zones
- **Cluster quorum updates** showing expanded node count
- **Network connectivity** establishment for new nodes
- **Storage integration** completion messages

---

## **Step 2: Monitor Scale-Out Process**

### **GUI Monitoring Tasks**

**⏱️ Estimated Monitoring Time: 6-8 minutes**

Access the Qumulo GUI and monitor the following during the node addition operation:

#### **Cluster Overview Dashboard**
- **Node count increase** from existing count to new total
- **Capacity metrics** showing expanded storage availability
- **Performance indicators** reflecting increased throughput potential
- **Availability zone distribution** confirming proper Multi-AZ spread

#### **Node Status Monitoring**
- **New node appearance** in the cluster topology
- **Health status indicators** showing "Active" for all nodes
- **Network connectivity** validation across availability zones
- **Storage integration** progress for new nodes

#### **Performance Metrics**
- **Aggregate throughput** increases as new nodes integrate
- **IOPS capacity** expansion with additional compute resources
- **Cache performance** improvement with expanded cache pools
- **Load distribution** across the enlarged cluster

![node add GUI 1](/static/images/elasticity/42_02.png)

![node add GUI 2](/static/images/elasticity/42_03.png)

::alert[**Why does it appear that no clients are rebalanced to new nodes??** In Multi-AZ clusters we utilize Network Load Blancing to direct clients to nodes.  Stick sessions are enabled and thus existing clients being directed to specific cluster nodes will not immediately get directed to added nodes.  As connections are started, stopped, and added over time they will begin to be directed by AWS NLB to the new nodes.  

In a Single-AZ cluster we use floating IP addresses, those will move with node adds and clients using those migrated floating IPs will immediately begin using the new nodes.]


You can also see new nodes in the EC2 console of AWS:

![node add EC2 console](/static/images/elasticity/42_04.png)

---

## **Step 3: Validate Scale-Out Success**

### **Post-Addition Verification**

After the node addition completes, verify the following:

#### **Cluster Health Checks**
- **✅ All nodes active** and responsive in the cluster
- **✅ Node count** matches expected total (original + 2 additional)
- **✅ Multi-AZ distribution** properly spread across availability zones
- **✅ Network connectivity** validated between all nodes
- **✅ Storage integration** complete for new nodes

#### **Performance Validation**
- **✅ Aggregate capacity** increased by expected amount
- **✅ Throughput potential** enhanced with additional compute
- **✅ Cache performance** improved with expanded cache pools
- **✅ Load balancing** effective across all nodes
- **✅ Response times** maintained or improved

#### **Configuration Verification**
- **✅ Floating IP addresses** properly distributed
- **✅ DNS resolution** working for all cluster endpoints
- **✅ Security groups** correctly configured for new nodes
- **✅ Backup integration** includes new nodes in protection scope

### **Expected Capacity Increase**

With 2 additional nodes added:
- **Storage capacity** increased by node-specific capacity amount
- **Performance throughput** enhanced by additional compute resources
- **Cache capacity** expanded for improved file access performance
- **Fault tolerance** improved with greater node redundancy

---

## **Operational Considerations**

### **Performance Optimization**

After node addition:
- **Allow rebalancing** to complete for optimal performance
- **Monitor performance metrics** to establish new baselines
- **Validate client connectivity** to all cluster endpoints
- **Test failover scenarios** to confirm enhanced fault tolerance

### **Cost Implications**

Adding nodes increases:
- **EC2 instance costs** for additional compute resources
- **Storage costs** for expanded persistent storage
- **Network transfer costs** for Multi-AZ communication
- **Overall operational costs** for expanded infrastructure

### **Maintenance Planning**

Consider for future operations:
- **Backup strategies** must account for increased capacity
- **Monitoring systems** should track expanded cluster metrics
- **Upgrade procedures** will require coordination across more nodes
- **Security policies** must be validated for new nodes

::alert[**Performance Note**: Data rebalancing occurs automatically in the background after node addition. While this process doesn't impact service availability, it may take time to complete depending on existing data volume.]

::alert[**Scaling Tip**: Adding nodes in three (3, 6, 9) is often more efficient for Multi-AZ deployments as it maintains balanced distribution across availability zones.]

::alert[**Cost Awareness**: Each additional node increases ongoing operational costs. Monitor usage patterns to ensure the scale-out provides appropriate value for your workload requirements.]{type="warning"}