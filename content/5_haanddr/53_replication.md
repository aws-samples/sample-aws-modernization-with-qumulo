---
title: "Replication Relationships"
weight: 53
---

## Understanding Qumulo Replication Types

Before diving into continuous replication, it's important to understand the three replication approaches Qumulo offers:

### **Continuous Replication**
- **Real-time scanning** - Qumulo Core continuously scans modified files for changed regions
- **Immediate transfer** - Only changed data blocks are transferred to the target cluster as they occur
- **Automatic snapshots** - Uses snapshots internally to generate consistent point-in-time copies
- **Single version target** - Target directory contains only the most recent snapshot (previous ones are deleted automatically)
- **Use case** - Ideal for disaster recovery scenarios requiring minimal data loss

### **Snapshot-Based Replication**
- **Scheduled transfers** - Replication occurs at specific times based on snapshot policies
- **Version preservation** - Multiple snapshots are maintained on the target cluster for historical recovery
- **Batch processing** - Data is transferred in scheduled batches rather than continuously
- **Use case** - Better for backup scenarios where historical versions are needed

### **Snapshot-Based Replication with Continuous Replication**
- **Real-time immediate transfers** - Changed data blocks are transferred to the target cluster as they occur and policy snapshots are kept
- **Version preservation** - Multiple snapshots are maintained on the target cluster for historical recovery
- **Batch processing** - Data is transferred in scheduled batches and continuously
- **Use case** - Best for scenarios where continuous data replication is required but policy snapshots need to be retained.  

**Key Difference**: Continuous replication provides near real-time protection but maintains only current data on the target, while snapshot-based replication provides historical versions but with larger recovery point objectives (RPO).  Continuous replication runs as soon as changes are detected to the source directory. Snapshot policy replication replicates snapshots created by linked policies and preserves the snapshots on the target cluster. Policy snapshots will be queued and replicated before continuous replication runs.

---

## How Continuous Replication Works

### **Initial Synchronization**
1. **Snapshot creation** - Takes an initial snapshot of the source directory
2. **Full transfer** - Transfers complete dataset to target directory
3. **Target setup** - Target directory becomes read-only for client access
4. **Relationship establishment** - Continuous monitoring begins

### **Ongoing Replication Process**
1. **File modification scanning** - Qumulo Core continuously monitors source directory for changes
2. **Changed region identification** - Only modified blocks are identified for transfer
3. **Incremental transfer** - Changed data is sent to target cluster
4. **Snapshot management** - Previous snapshots on target are automatically deleted to maintain only current version

### **Consistency Guarantees**
- **Point-in-time consistency** - Target directory represents a consistent snapshot at transfer completion
- **Automatic crash recovery** - Interrupted transfers resume automatically
- **Version synchronization** - Both clusters must run compatible Qumulo Core versions

---

## Prerequisites and Requirements

### **Version Compatibility**
Qumulo Core supports replication between different versions with specific requirements:

- **Qumulo Core 6.0.0+ (Current)** - Compatible with versions up to eight quarters in the future
- **Qumulo Core 5.0.1-6.0.0** - Compatible between current version and up to two previous/future quarterly versions
- **Qumulo Core 2.12.0+ Required** - At least one cluster (source or target) must run version 2.12.0 or higher

### **Network Requirements**
- **Port 3712** - Default replication port on all target cluster nodes
- **Firewall configuration** - Must allow communication between clusters
- **Floating IP recommended** - Use floating IP addresses for target cluster access

---

## Target Directory Behavior

### **Read-Only State**
When a replication relationship is created:
- **Target directory becomes read-only** - All client write access is blocked
- **Administrative functions preserved** - Cluster management operations continue normally
- **Automatic restoration** - Directory returns to read-write when relationship is deleted

### **Root Directory Considerations**

::alert[**Warning**: Replicating to the root directory (`/`) makes the entire target cluster read-only and may impact administrative functions like upgrades.]{type="warning"}

---

## 1. Create a Replication Relationship

Now let's create a continuous replication relationship between your primary and secondary clusters to protect the `/userdata` directory.

### **Access the Primary Cluster UI**

1. On your **Windows workstation**, open Chrome and access the **Primary Qumulo GUI** (`https://demopri.qumulo.local`)
2. Log in with username `admin` and password `!Qumulo123`

### **Navigate to Replication**

1. In the left sidebar, navigate to **Cluster > Replication**

![Create Replication Relationship](/static/images/haanddr/53_01.png)

2. Click **"Create Relationship"** button

### **Configure Source Settings**

1. **Source Directory Path**: `userdata/`
2. **Target Directory Path**: `userdata/`
3. **Target IP Address**: Copy this IP address from the demosec.qumulo.local cluster browser window

![Replication destination ip](/static/images/haanddr/53_05.png)

![Replication details 1](/static/images/haanddr/53_02.png)

4. **Port Number**: Select Default
5. **Replication Mode**: Snapshot Policy with Continuous Replication
6. **Snapshot Policies**: Select Frequent-protection created in the last section.
7. **Expire Snapshot on Target**: Select "Same as Policy"

![Replication details 2](/static/images/haanddr/53_03.png)

8. **Enable Replication**: Ensure this is checked

### **Advanced Settings**

- **NFS ID Mapping**: Checked
- **Blackout Windows**: None configured initially

![Advanced Settings](/static/images/haanddr/53_04.png)

### **Create the Relationship**

1. Review your configuration settings
2. Click **"Create Relationship"**
3. The relationship will be created with a "Pending Authorization" status

![Relationship Created](/static/images/haanddr/53_06.png)

---

## 2. Authorize the Replication Relationship

The replication relationship must be authorized on the target cluster before data transfer can begin.

### **Access the Secondary Cluster UI**

1. Open a new browser tab and access the **Secondary Qumulo GUI** (`https://demosec.qumulo.local`)
2. Log in with username `admin` and password `!Qumulo123`

### **Authorize the Relationship**

1. Navigate to **Cluster > Replication** in the secondary cluster
2. You should see the pending relationship
3. Click **"Authorize"** next to the relationship

![Authorize Relationship](/static/images/haanddr/53_07.png)

4. Confirm the authorization by clicking **"Authorize Relationship"**

![Confirm Authorization](/static/images/haanddr/53_08.png)

### **Monitor Initial Synchronization**

Once authorized, the initial synchronization begins automatically:

1. **Return to the primary cluster UI**
2. Navigate back to **Cluster > Replication**
3. Observe the relationship status change from "Pending" to "Running"

![Replication Running](/static/images/haanddr/53_09.png)

The initial sync transfers all data from `/userdata` on the primary cluster to `/userdata` on the secondary cluster.

---

## 3. Monitor Replication Status

The replication monitoring interface provides detailed status information:

![replication monitoring](/static/images/haanddr/53_10.png)

#### **Status Indicators**

Observe the various status icons and their meanings:

![replication status](/static/images/haanddr/53_11.png)

#### **Progress Tracking**

Monitor the replication progress through:

1. **Percentage completion** - Shows progress based on files and data transferred
2. **Throughput metrics** - Current transfer rates and performance
3. **Runtime tracking** - Elapsed time for current job
4. **Data statistics** - Files transferred, remaining, and total size

---

## 4. Verify Target Directory State

Let's verify that the target directory is properly configured and receiving data.

### **Create the destination userdata share**

The destination share needs to be created.  

1. **Create the userdata share** on demosec.qumulo.local select Sharing -> SMB Shares.  Select create share and type userdata for the folder and share name.  Click **Create Share**

![share permissions](/static/images/haanddr/53_20.png)
![share permissions 2](/static/images/haanddr/53_22.png)

2. **Connect your Windows desktop SMB to the userdata share with admin privledges**

```
net use \\demopri.qumulo.local\userdata /delete /y
net use \\demosec.qumulo.local\userdata /delete /y
net use \\demopri.qumulo.local\userdata /user:admin !Qumulo123
net use \\demosec.qumulo.local\userdata /user:admin !Qumulo123
```

### **Check Target Directory on Secondary Cluster**

1. **In the secondary cluster UI**, navigate to **Integrated Analytics**
2. Browse to the root directory and look for `/userdata` to see that the replication data has appeared on the secondary cluster.

![replica view analytics](/static/images/haanddr/53_12.png)

3. **Browse to the share on the secondary cluster `\\demosec.qumulo.local\userdata`
4. **Note**: The directory should appear but will be **read-only** for client access



### **Verify Read-Only State**

1. **On your Windows workstation**, try to map the secondary cluster
2. Attempt to access `\\demosec.qumulo.local\userdata`
3. You should be able to **read files** but **not write** to the replicated directory

![Target Directory](/static/images/haanddr/53_13.png)

4. **Verify replica destination snapshots** by accessing `\\demosec.qumulo.local\userdata\.snapshot`.  You will notice destination snapshots are replicated and accessible.

![Target Directory snapshots](/static/images/haanddr/53_14.png)

---

## 5. Test Continuous Replication

Generate some file activity to observe continuous replication in action.

### **Create Test Files on Primary**

1. **On your Windows workstation**, navigate to the primary cluster share `\\demopri.qumulo.local\userdata`
2. Create a new folder: `replicationtest`
3. Add several files (right click, create files)

![Create Test Files](/static/images/haanddr/53_14.png)

### **Monitor Replication Activity**

1. **Return to the primary cluster UI** replication status page
2. **Refresh the page** to see updated statistics
3. Observe how the **files transferred count** increases
4. Note the **throughput metrics** during active replication

![Active Replication](/static/images/haanddr/53_15.png)

### **Optional CLI Monitoring**

You can use the `qq` CLI to get detailed replication status as well:

**Retrieve Source Relationships**

```
qq --host demopri.qumulo.local login --u admin --p '!Qumulo123'
qq --host demopri.qumulo.local replication_list_source_relationships
```

Make note of the replication relationship ID

![Active Replication CLI](/static/images/haanddr/53_16.png)

**Get specific information about a source relationship**

```
qq --host demopri.qumulo.local login --u admin --p '!Qumulo123'
# Make sure to enter your specific replication ID into the following command
qq --host demopri.qumulo.local replication_get_source_relationship_status --id {}}
```

![Active Replication CLI Details](/static/images/haanddr/53_17.png)

::alert[**Good to know:**: A full list of qq cli commands can be found in the Qumulo command line reference guide: https://docs.qumulo.com/qq-cli-command-guide/]

---

## Disaster Recovery: Failing Over and Reconnecting Replication

This section demonstrates how to perform a planned failover by removing the replication relationship, making the target directory writable, and validating the change. We’ll also explain the requirements for failback in a real disaster recovery (DR) scenario and show how to reconnect replication without requiring a full resync.

---

### 1. **Failing Over: Breaking the Replication Relationship**

Failing over involves **removing the replication relationship** from the source or target cluster, which makes the previously read-only target directory writable.

#### **Break the Relationship from the Primary Cluster**

1. In the **Primary Qumulo GUI** (`https://demopri.qumulo.local`), navigate to **Cluster > Replication**.
2. Locate the `userdata-disaster-recovery` relationship (or your chosen replication relationship).
3. Click the **ellipsis (...)** menu next to the relationship and select **Delete**.
   
   ![Delete Replication Relationship](/static/images/haanddr/53_18.png)

4. Confirm deletion. You’ll see a warning about converting the destination to read-write.

   ![Confirm Relationship Deletion](/static/images/haanddr/53_19.png)

#### **Alternate: Break the Relationship from the Secondary Cluster**

You can also break the relationship from the target (secondary) cluster, if for some reason the primary cluster is unavailable:

---

### 2. **Validate Target Directory Is Now Writable**

Once the relationship is removed, the target directory is instantly switched from read-only to read-write.

#### **Test Write Access via Windows Client**

1. On your **Windows workstation**, open File Explorer.
2. Navigate to `\\demosec.qumulo.local\userdata`.
3. Try to create a new folder or file inside `userdata`.
   - **Success means failover is complete.**

   ![Write Access Enabled](/static/images/haanddr/53_21.png)

   ---

## Next step

Proceed to **Section 6.0 – Cloud Data Fabric** explore Qumulo's Cloud Data Fabric (CDF) technology.

---