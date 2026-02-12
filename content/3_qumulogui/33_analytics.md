---
title: "Analytics Overview"
chapter: false
weight: 33
---

The Analytics section provides comprehensive monitoring and insights into your Qumulo cluster's performance, capacity usage, and activity patterns. This powerful toolset helps administrators understand system behavior, identify bottlenecks, and make data-driven decisions.

Use the **Analytics dropdown menu** (shown below) to navigate between the different analytics views: Integrated Analytics, Capacity Explorer, Capacity Trends, and Activity hotspots.

![Analytics Main Screen](/static/images/qumulogui/33_01.png)

## What Analytics Provides

The Analytics section offers three main categories of insight:

- **Real-time Performance Monitoring** - Live throughput, IOPS, and client activity
- **Capacity Analysis** - Storage usage patterns and growth trends over time  
- **Activity Hotspots** - Identification of high-activity files, directories, and clients

## Integrated Analytics Dashboard

The main analytics view displays current cluster activity with real-time updates:

![Analytics Dashboard](/static/images/qumulogui/33_02.png)

Key metrics visible at a glance:
- **Current throughput** (read/write operations)
- **IOPS activity** across the cluster
- **File and metadata operations** in progress
- **Active client connections** and their activity levels

## Capacity Explorer

Navigate storage usage with interactive visualizations that respond to your exploration:

![Capacity Explorer](/static/images/qumulogui/33_03.png)

![Capacity Explorer Detail](/static/images/qumulogui/33_04.png)

::alert[**Interactive Tip:** Try clicking on directory segments and graph elements - the interface is highly responsive and will drill down into more detailed views.]

## Capacity Trends

### Historical Usage

::alert[**Note:** Historical usage is not real time, this is updated hourly so there may be no data in this section.  Check back later in the lab to see information.]

Track storage consumption over selectable time periods:
- **72 hours** - Short-term usage patterns
- **30 days** - Monthly growth analysis  
- **52 weeks** - Annual capacity planning

The timeline shows breakdown by data, metadata, and snapshots with interactive point-in-time details.

![Capacity Trends](/static/images/qumulogui/33_05.png)

### Capacity Changes
Monitor data flow with **data-in** and **data-out** visualizations that help identify:
- Usage spikes or unusual activity
- Most significant capacity changes by path
- Trends that may require attention
- Ability to select changes to see where in the filesystem those changes happened

![Capacity Changes](/static/images/qumulogui/33_06.png)

## Activity Analysis

### Performance Hotspots
Identify areas of high activity:
- **Throughput Hotspots** - Directories with highest data transfer rates
- **IOPS Hotspots** - Areas with intensive metadata or small-file operations

### Client and Path Activity
Track which clients and file paths are most active:
- **Top 40 active clients** with drill-down capability
- **Top 10 active paths per client** for detailed analysis
- **Real-time activity correlation** between users and data

## Practice Exercise

With your load testing running, explore the Analytics section:

1. **Observe live metrics** - Notice how the dashboard updates with your cluster activity
2. **Navigate the Capacity Explorer** - Click through different directory levels
3. **Check Activity views** - Identify which paths show the most activity from your load testing
4. **Experiment with time ranges** - Change the historical view periods and observe the differences

---

✅ **Key Benefits:** Analytics provides both **real-time operational insight** and **historical trend analysis**, essential for performance tuning, capacity planning, and troubleshooting.

---

**Next:** Proceed to **Section 3.4 – Sharing Management** where we'll explore how to configure NFS exports, SMB shares, and S3 buckets.
