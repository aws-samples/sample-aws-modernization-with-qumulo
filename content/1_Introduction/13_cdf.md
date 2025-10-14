---
title: "Cloud Data Fabric Introduction" 
chapter: true
weight: 3
---

# Introduction to Qumulo Cloud Data Fabric (CDF)

## Introduction

Qumulo Cloud Data Fabric (CDF) is an enterprise-wide cloud data platform designed to provide access to unstructured data regardless of location. It creates a single, globally-consistent file system that spans edge, core data centers, and cloud environments, enabling teams to share data across long distances with minimal latency and without version conflicts.

CDF provides a transformative approach to data management by:
* Creating local access to data regardless of where it resides
* Enabling real-time collaboration between geographically dispersed teams
* Simplifying data governance through unified access controls
* Accelerating time-to-value by minimizing data transfer requirements

## CDF Architecture

### Hub and Spoke Model
CDF is built on a hub-and-spoke architecture where:
* **Hub**: Central Qumulo instance that hosts the source data
* **Spoke**: Remote Qumulo instances that can access the hub's data
* **Portal**: Connection between hub and spoke that defines which directories are shared

![Hub and Spoke Model](../images/cdf-portals.png)

### Data Portal Details
* Defined at a directory level (not entire file systems)
* Can be configured as read-only or bidirectional (read-write)
* Each portal supports one hub folder and up to 32 spokes
* Directories within a portal appear as if they're local to spoke clients

![Data Portal Details](../images/cdf-portal2.png)

### Data Synchronization Process
1. **Metadata First**: Directory structure and file metadata are synchronized immediately
2. **Data On-Demand**: File data blocks (4K) are only transferred when requested by a client
3. **Local Caching**: Accessed data is cached locally on the spoke for future requests
4. **Block-Level Changes**: Only modified blocks are synchronized, not entire files

![Data Synchronization Process](../images/cdf-caching.png)

### NeuralCache Intelligence in the CDF Portal Relationship

Within Qumulo Cloud Data Fabric (CDF), NeuralCache is the predictive caching engine that optimizes data access across portal-connected sites. When a directory is shared from a hub to one or more spokes via a CDF portal, NeuralCache continuously analyzes data access patterns on each spoke. By learning which files and blocks are most frequently or recently accessed, NeuralCache anticipates future data requests and proactively prefetches relevant data from the hub into the spoke’s local cache before users request it.

This predictive approach ensures that up to 90% of global read requests on spoke endpoints are served directly from local cache, significantly reducing WAN traffic and latency. NeuralCache’s heat-scoring system dynamically prioritizes and retains the most active data in cache, while evicting less frequently used blocks, further enhancing performance and scalability for distributed teams. As a result, users experience local-like performance when accessing remote data through CDF portals, enabling real-time collaboration and efficient workflows across geographically dispersed environments.

![NeuralCache Detail](../images/cdf-neuralcache.png)

## CDF Common Use Cases

![Common Use Cases](../images/cdf-usecase.png)

### Cloud Bursting for Compute-Intensive Workloads
* **Challenge**: Need more computing power for rendering or analysis
* **Solution**: Express on-premises data to cloud instances via CDF
* **Benefit**: Scale compute resources without copying entire datasets

### Real-Time Global Collaboration
* **Challenge**: Teams in different locations need to work on the same files
* **Solution**: Set up bidirectional portals between locations
* **Benefit**: Everyone works on the same data without version conflicts

### AI/ML Pipeline Optimization
* **Challenge**: AI engines need access to large datasets without moving them
* **Solution**: Express on-premises data to cloud-based AI services
* **Benefit**: Process data where it makes most sense without duplication

### Edge Data Collection with Central Processing
* **Challenge**: Data collected at the edge needs central processing
* **Solution**: Set up portals from edge locations to central hub
* **Benefit**: Data appears instantly at the hub without full transfer

## Key Takeaways

* **Global Data Accessibility:** Qumulo Cloud Data Fabric (CDF) provides a single, globally-consistent file system that spans data center, cloud, and edge, enabling real-time data access and collaboration across geographically distributed teams.
* **Not Traditional Replication:** Unlike legacy solutions, CDF does not replicate entire datasets. Instead, it synchronizes metadata globally and transfers only the required data blocks on demand, minimizing WAN traffic and eliminating version conflicts.
* **Strict Consistency:** All endpoints maintain a unified, up-to-date view of data, with guaranteed consistency and immediate metadata synchronization across locations.
* **Intelligent Caching and NeuralCache:** Advanced caching algorithms-including NeuralCache-anticipate data needs, serving 90% of global read requests from cache to reduce latency and optimize performance for distributed workloads.
* **Unified Management and Analytics:** Manage and monitor all unstructured data through a single platform, with advanced analytics and real-time visibility into data usage, performance, and activity at every endpoint.
* **Flexible Architecture and Use Cases:** The hub-spoke architecture with data portals supports directory-level sharing and bidirectional synchronization, making CDF ideal for use cases such as real-time collaboration, cloud bursting for AI/ML, and edge data ingest-while differentiating itself from traditional replication-based solutions.
* **Operational Efficiency and Cost Savings:** By only moving data when it is needed and optimizing resource utilization, CDF reduces infrastructure costs, improves scalability, and accelerates business cycles.

## Next Steps

* Review Workshop Prerequisites
* Set Up Your AWS Environment


