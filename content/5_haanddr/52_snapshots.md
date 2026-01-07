---
title: "Snapshot Management"
weight: 52
---

Snapshots provide point-in-time protection for your data without requiring additional storage for unchanged files. Qumulo's snapshot technology allocates new storage only for modified data while allowing original and new versions to share unchanged portions, making it extremely space-efficient for frequent backups.

In this section, you'll create manual snapshots and configure automated snapshot policy using the Qumulo web interface.

---

## Understanding Qumulo Snapshots

### **Point-in-time Data Protection Fundamentals**

Qumulo snapshots capture the entire file system state at a specific moment, including:

- **File contents and metadata** - All files, directories, and their attributes
- **Permissions and ownership** - Complete security context preservation  
- **Directory structure** - Full filesystem hierarchy and relationships

### **Space-Efficient Storage**

A snapshot is an entry for every version of file system elements such as files, directories, creation and modification timestamps, permissions, and so on. Each new entry points only to changed data and, to allow original and new entries to share data, Qumulo Core writes the entries alongside each other. Snapshots on Qumulo Core provides significant storage advantages:

- **Initial snapshot** - Takes virtually no additional space (just metadata)
- **Incremental changes** - Only modified blocks consume additional storage
- **Shared unchanged data** - Common files between snapshots share the same storage blocks
- **Automatic deduplication** - Identical data blocks are stored only once across all snapshots

---

## Create a Manual Snapshot

First, we'll create a baseline snapshot of the primary cluster to establish our starting point.

### **Access the Primary Cluster UI**

1. On your **Windows workstation**, open Chrome and click the **"Primary Qumulo GUI"** bookmark (`https://demopri.qumulo.local`)
2. Log in with:
   - **Username**: `admin`
   - **Password**: `!Qumulo123`

### **Create the Baseline Snapshot**

1. Navigate to **Cluster > Snapshots** in the left sidebar
2. Click **"Take Snapshot"** button in the upper right
3. Configure the snapshot:
   - **Name**: `userdata_baseline`
   - **Path**: `/userdata` (root directory - captures entire filesystem)
4. Click **"Save"**

![take single snapshot](/static/images/haanddr/52_01.png)

The snapshot creation completes almost instantly since it's primarily a metadata operation.

![take single snapshot saved](/static/images/haanddr/52_02.png)

---

## Configure Automated Snapshot Policy

Now we'll set up a policy to automatically create frequent snapshots for ongoing protection.

### **Create a Snapshot Policy**

1. Still in **Cluster > Snapshots**, click the **"Policies"** tab
2. Click **"Create Policy"** button
3. Configure the policy settings:
   
   | Setting | Value | Purpose |
   |---------|-------|---------|
   | **Policy Name** | `frequent-protection` | Descriptive policy identifier |
   | **Directory Path** | `/userdata` | Protect the userdata folder |
   | **Take a Snapshot** | Every 1 minute | Frequent capture for demo purposes |
   | **In the Time Window** | 24 Hours | Take them throughout the day at all hours |
   | **On the following days** | Every Day | Set this to take snapshots on every day of the week |
   | **Delete Each Snapshot** | Automatically after 1 hour | Keep 60 snapshots |
   | **Enabled** | ✓ Checked | Activate policy immediately |

4. Click **"Create Policy"**

![snapshot policy create](/static/images/haanddr/52_03.png)

![snapshot policy complete](/static/images/haanddr/52_04.png)

### **Understanding Snapshot Schedules**

Qumulo snapshot policies support flexible scheduling options:

- **Interval-based** - Every X minutes/hours (like our 1-minute example)
- **Time-based** - Specific times of day (e.g., daily at 2:00 AM)
- **Day-based** - Specific days of the week or month
- **Timezone-aware** - Policies respect cluster timezone settings

### **Retention Policy Behavior**

The retention setting determines snapshot lifecycle:

- **Automatic cleanup** - Older snapshots are deleted when retention expires
- **Rolling window** - Maintains a consistent number of recent snapshots
- **Space management** - Prevents unlimited snapshot accumulation

---

## Monitor Snapshot Creation

Watch the automated policy create snapshots over the next few minutes.

### **View Active Snapshots**

1. Return to the **"Snapshots"** tab (not Policies)
2. Observe the snapshot list - you should see:
   - Your manual `baseline` snapshot
   - Automated snapshots appearing every 1 minute with timestamps

### **Snapshot Naming Convention**

Policy-generated snapshots use automatic naming:
- **Format**: `policy-name_YYYY-MM-DD_HH-MM-SS`
- **Example**: `frequent-protection_2025-07-25_15-10-00`

![snapshots](/static/images/haanddr/52_05.png)

---

## Explore Snapshot Storage Efficiency

Connect the Windows system to the share as the admin user:

```
net use \\demopri.qumulo.local\userdata /user:admin !Qumulo123
```

### **Generate Some File Changes**

To demonstrate space efficiency, let's create some file activity:

1. On your **Windows workstation**, open **File Explorer**
2. Navigate to the share `\\demopri.qumulo.local\userdata\`
3. Create a new folder: `snapshot-test`
4. Inside this folder, create a few text files with different content
5. Wait 1 minute for a new snapshot to be created.
6. Open the file and make another change by adding a line of text.

![snapshots file creation](/static/images/haanddr/52_06.png)

Windows Previous Versions shows older "snapshot" versions of files natively.  Right click on the file you created, select Previous Versions tab, and see the older version of your file.  If you click open you will see it without the changes made in step 6 above:

![Previous Versions](/static/images/haanddr/52_07.png)

### **Observe Space Growth in Qumulo UI**

Return to **Analytics > Capacity** and refresh the page. You'll notice:
- **Minimal space increase** - Only the new/changed files consume additional storage
- **Efficient scaling** - Each snapshot adds storage only for its unique changes

### **View Snapshot Space Usage via CLI**

Since the Analytics > Capacity Trends page updates only hourly, we'll use the `qq` CLI to see real-time snapshot space consumption.

On your **Linux workshop instance**, open a terminal and run:

```
qq --host demopri.qumulo.local login --u admin --p '!Qumulo123'
qq --host demopri.qumulo.local snapshot_get_total_used_capacity
```

![total space consumption](/static/images/haanddr/52_10.png)

```
qq --host demopri.qumulo.local snapshot_list_snapshots | jq --argjson capacity "$(qq --host demopri.qumulo.local snapshot_get_capacity_used_per_snapshot)" '.entries[] as $snap | $capacity.entries[] | select(.id == $snap.id) | {name: $snap.name, capacity_MB: ((.capacity_used_bytes | tonumber) / 1024 / 1024 | floor), capacity_bytes: (.capacity_used_bytes | tonumber)}' | jq -s 'sort_by(.capacity_bytes) | reverse[]'
```

![snapshot space consumption](/static/images/haanddr/52_09.png)

This command shows each snapshot with its storage consumption in both megabytes and bytes, sorted by size.

### **Create More Data and Observe Changes**

1. Navigate to one of the worker folders and delete some data:

![delete data](/static/images/haanddr/52_08.png)

2. Wait for the next snapshot policy cycle (1 minute)

3. Run the snapshot space command again to see how deleted data affects snapshot storage:

```
qq --host demopri.qumulo.local login --u admin --p '!Qumulo123'
qq --host demopri.qumulo.local snapshot_get_total_used_capacity
qq --host demopri.qumulo.local snapshot_list_snapshots | jq --argjson capacity "$(qq --host demopri.qumulo.local snapshot_get_capacity_used_per_snapshot)" '.entries[] as $snap | $capacity.entries[] | select(.id == $snap.id) | {name: $snap.name, capacity_MB: ((.capacity_used_bytes | tonumber) / 1024 / 1024 | floor), capacity_bytes: (.capacity_used_bytes | tonumber)}' | jq -s 'sort_by(.capacity_bytes) | reverse[]'
```

::alert[**Capacity Analytics**: The Capacity Trends section of the Qumulo GUI provides excellent information about snapshot consumption over time.  This information is rolled up hourly and is highly beneficial in a production environment to observe total snapshot space consumption.]

---

## Access the Snapshot Directory

Qumulo makes snapshots accessible through a special hidden directory that clients can browse directly.

### **Windows Client Access**

1. In **File Explorer**, navigate to the primary Qumulo cluster userdata share.
2. Type the following path in the address bar:

```
\\demopri.qumulo.local\userdata\.snapshot
```

3. Press **Enter** to access the snapshot directory

![snapshot directory](/static/images/haanddr/52_11.png)

### **Browse Snapshot Contents**

In the `.snapshot` directory, you'll see:

- **Folders named by snapshot** - Each snapshot appears as a subdirectory
- **Complete filesystem view** - Every snapshot contains the full filesystem at that point in time
- **Read-only access** - All snapshot contents are protected from modification

### **Compare Snapshot Contents**

1. Open the `baseline` snapshot folder
2. Open one of the recent policy-generated snapshots in a separate window
3. Compare the contents - you should see differences based on files created after the baseline

---

## Snapshot Restoration Concepts

While we won't perform a full restoration in this workshop, understand these key concepts:

### **File-Level Recovery**

- **Individual files** - Copy specific files from `.snapshot` directories back to live filesystem
- **Drag-and-drop** - Simple recovery using standard file operations
- **Selective restoration** - Recover only what you need without full filesystem restoration

### **Directory-Level Recovery**

- **Complete directories** - Restore entire folder structures from snapshots through the `.snapshot` directory or through previous versions tab
- **Point-in-time consistency** - All files in a directory are from the same snapshot moment
- **Preserve relationships** - Directory structures and file relationships remain intact

![snapshot directory restore previous versions](/static/images/haanddr/52_12.png)

---

## Key Observations

As you work through this section, note these important characteristics:

- **Instant creation** - Snapshots appear immediately regardless of data size
- **Minimal impact** - Ongoing filesystem operations continue normally during snapshot creation
- **Space efficiency** - Storage consumption grows only with actual data changes
- **User accessibility** - Snapshots are directly browsable by end users through `.snapshot`
- **Automated management** - Policies handle creation and cleanup without manual intervention

---

## Next Steps

In **Section 5.3**, we'll configure continuous replication relationships between your primary and secondary clusters, using snapshots as the foundation for cross-cluster data protection.

::alert[**Best Practice**: In production environments, consider multiple snapshot policies with different frequencies and retention periods - for example, frequent snapshots for recent changes and longer-term snapshots for historical recovery points.]