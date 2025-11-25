---
title: "Cluster Administration"
chapter: false
weight: 35
---

The Cluster section provides comprehensive system administration tools for managing your Qumulo environment. From monitoring cluster health to configuring protocols and managing data protection, this section centralizes all core administrative functions.

![Cluster Menu](/static/images/qumulogui/35_01.png)

## Cluster Overview

The overview dashboard provides real-time visibility into your cluster's operational status:

![Cluster Overview Dashboard](/static/images/qumulogui/35_02.png)

### Key Information Displayed
- **Capacity Summary**: Total used, available, and usable storage with visual indicators
- **Cluster Health**: Node status (online/offline), system alerts, and warnings
- **System Details**: Cluster version, uptime, and configuration information
- **Node Information**: Individual node status, names, and MAC addresses

This centralized view serves as your primary health check for cluster operations.

## Snapshots Management

### Snapshot Overview
View and manage all saved snapshots from the main snapshots page:

- **Manual Snapshots**: Create instant snapshots using the "Take Snapshot" button
- **Snapshot History**: Browse existing snapshots with creation dates and sizes
- **Snapshot Operations**: Delete or restore from previous snapshots

## Data Movement

### Replication
Configure continuous replication between Qumulo clusters for disaster recovery:

**Replication Features:**
- **Continuous synchronization** of directory changes
- **Snapshot-based consistency** for point-in-time recovery
- **Incremental transfers** to minimize bandwidth usage
- **Bi-directional support** for flexible DR architectures

::alert[**Note:** Replication relationships require authorization on both source and target clusters before data transfer begins.]

### Copy to/from S3
Integrate with cloud storage for backup and archival:

Configure data movement between your cluster and S3-compatible storage for:
- **Cloud backup** and archival strategies
- **Data migration** between environments
- **Hybrid cloud** workflows

## Configuration Management

### Network Configuration
Manage cluster networking and connectivity:

![Network Configuration](/static/images/qumulogui/35_03.png)

- **Static IP configuration** for production environments
- **DHCP settings** for dynamic addressing
- **Interface management** and bonding options

### Audit Configuration
Configure comprehensive audit logging for compliance and security:

**Audit Capabilities:**
- **Real-time export** to remote syslog servers
- **File system operation** tracking
- **Configuration change** logging
- **Integration** with SIEM tools like Splunk, Elasticsearch

## Protocol Configuration

### File and Object Protocols
Configure global settings for data access protocols:

**FTP Settings:**
**SMB Settings:**
**S3 Settings:**

### Authentication & Authorization

**Active Directory Integration:**
**LDAP Configuration:**
**Role Management:**
**Local Users and Groups:**

## Exploration Exercise

Take time to explore the Cluster section:

1. **Review cluster overview** - Check the current health status and capacity
2. **Browse snapshots** - See any existing snapshots or policies
3. **Examine network configuration** - Understand your current network setup
4. **Check protocol settings** - Review enabled protocols and their configurations
5. **Explore authentication options** - Understand identity management capabilities

---

✅ **Key Takeaway:** The Cluster section provides centralized administration for all system-level configurations, from basic monitoring to advanced features like multitenancy and replication.

---

**Next:** Proceed to **Section 3.6 – APIs & Tools** where we'll explore developer resources and automation capabilities.
