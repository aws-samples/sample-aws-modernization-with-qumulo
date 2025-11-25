---
title: "Disaster Recovery with Qumulo"
chapter: true
weight: 5
---

## Overview

This module explores Qumulo's comprehensive disaster recovery and data protection capabilities, demonstrating how to safeguard your data across multiple environments and ensure business continuity. You'll learn to implement various protection strategies, from point-in-time snapshots to continuous cross-cluster replication and cloud-based archival solutions.

Qumulo's disaster recovery tools provide multiple layers of protection, enabling you to choose the appropriate strategy based on your Recovery Time Objectives (RTO) and Recovery Point Objectives (RPO). The integrated approach allows seamless data movement between on-premises, cloud, and hybrid environments while maintaining operational efficiency.

## Key Takeaways

By the end of this module, participants will be able to:

- **Create and manage snapshots** to protect data at specific points in time with space-efficient storage
- **Configure continuous replication relationships** between clusters for real-time data protection across locations
- **Implement proper failover and failback procedures** to maintain business continuity during disasters
- **Use Copy to Amazon S3** to offload or archive data for long-term storage and cost optimization
- **Use Copy from Amazon S3** to ingest external data into Qumulo clusters for processing and analysis
- **Monitor and validate** disaster recovery operations to ensure data integrity and availability

## Topics Covered

### **Snapshot Management**
- Point-in-time data protection fundamentals
- Snapshot creation, scheduling, and retention policies
- Space-efficient snapshot storage and management
- Snapshot restoration and recovery procedures

### **Continuous Replication Relationships**
- Understanding the two types of replication approaches used in Qumulo core - continuous and snapshot-based
- Creating and authorizing replication relationships between source and target clusters
- Configuring replication parameters including blackout windows and bandwidth management
- Managing target directory permissions and read-only states during replication
- Monitoring replication status, throughput, and progress tracking
- Handling version compatibility requirements across different Qumulo Core releases

### **Failover and Failback Operations**
- Planning and executing planned failovers with minimal data loss
- Managing emergency failover scenarios when source clusters become unavailable
- Understanding the "Make Target Writable" process for disaster scenarios
- Implementing proper failback procedures using "Reconnect Relationship" functionality
- Coordinating client access redirection during disaster recovery events
- Testing failover procedures and validating recovery capabilities

### **Cloud Integration and Archival**
- Copy to Amazon S3 for long-term data retention
- Cost-effective archival strategies and lifecycle policies
- Copy from Amazon S3 for data ingestion and processing
- Hybrid cloud disaster recovery architectures

## Workshop Environment

The workshop provides hands-on experience with disaster recovery scenarios using:

- **Multi-cluster setup** for demonstrating continuous replication relationships between primary and secondary sites
- **Pre-configured replication policies** to explore different protection strategies and blackout windows
- **Sample datasets** for testing snapshot creation, replication, and recovery operations
- **Monitoring dashboards** to track continuous replication status and performance metrics
- **Automated scripts** for simulating disaster scenarios and practicing failover/failback procedures

This practical approach allows you to experience real-world disaster recovery operations while understanding the underlying concepts and best practices for production deployments.

::alert[The examples and sample code provided in this workshop are intended to be consumed as instructional content. These will help you understand how disaster recovery strategies can be implemented while demonstrating best practices. These examples are not intended for use in production environments without proper testing and validation.]{type="warning"}

::alert[**Production Consideration**: Continuous replication increases cluster load and can cause latency delays depending on applications in use. Regular testing and validation of failover/failback procedures is essential for ensuring reliable disaster recovery capabilities in production environments.]

## Next Steps

In the following sections, you'll work through each disaster recovery capability, starting with snapshot management and progressing to continuous replication relationship setup with hands-on failover/failback exercises. Each section includes practical exercises that build upon previous concepts, culminating in a comprehensive disaster recovery implementation with tested failover capabilities.
