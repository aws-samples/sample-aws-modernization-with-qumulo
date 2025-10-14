---
title: "Deploying CNQ/Qumulo on AWS"
chapter: true
weight: 2
---

# Deploying CNQ/Qumulo on AWS

## **Overview**
This module provides comprehensive guidance for deploying **Cloud Native Qumulo (CNQ)** on AWS infrastructure. You'll learn the essential prerequisites, understand the two-stage deployment architecture, and gain hands-on experience with both persistent storage and compute infrastructure deployment using the pre-configured workshop environment.

CNQ's deployment model separates **persistent storage** from **compute resources**, enabling flexible scaling, high availability configurations, and cost-effective resource management. This architectural approach allows you to scale storage and compute independently based on your workload requirements.

## **Key Takeaways**
By the end of this module, you will:

- **Understand CNQ's two-stage deployment architecture** and how persistent storage and compute resources work together
- **Identify and validate essential AWS prerequisites** including VPC setup, IAM permissions, and network configurations
- **Deploy persistent storage infrastructure** using Terraform configurations in the workshop environment
- **Configure and deploy CNQ compute nodes** for both Single-AZ and Multi-AZ scenarios
- **Navigate the pre-configured workshop infrastructure** that automates deployment complexity
- **Access and manage deployed Qumulo clusters** through both web interface and command-line tools

## **Topics Covered**
- **Prerequisites and Infrastructure Requirements**
- **Client Infrastructure Deployment and Workshop Environment**
- **Persistent Storage Deployment** - The foundation layer for data durability
- **Compute Storage Deployment** - File system services and cluster operations

## **Workshop Environment**
The workshop provides a **fully automated deployment experience** where:
- AWS infrastructure is pre-configured with proper networking and security
- Terraform configurations are ready-to-use with workshop-specific variables
- Automated scripts handle the complexity of multi-stage deployments
- Comprehensive logging and monitoring provide visibility into deployment progress

This hands-on approach allows you to focus on understanding CNQ's architecture and deployment patterns rather than spending time on infrastructure setup and configuration management.

{{% notice warning %}}
The examples and sample code provided in this workshop are intended to be consumed as instructional content. These will help you understand how various AWS services can be architected to build a solution while demonstrating best practices along the way. These examples are not intended for use in production environments.
{{% /notice %}}
