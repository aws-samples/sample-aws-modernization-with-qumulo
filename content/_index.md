---
title: "Qumulo on AWS Workshop"
chapter: true
weight: 1
---

# **Welcome to the Qumulo on AWS Workshop!**  

![Partner Logo](/static/images/qlogo.png)


## **Welcome**  
Welcome, and thank you for joining this **Qumulo on AWS Workshop**! Whether you're exploring Qumulo for the first time or looking to deepen your expertise, this hands-on session will provide you with a clear understanding of how Qumulo's **ScaleAnywhere™ architecture** enables seamless data management across on-premises and cloud environments.  

Throughout this workshop, we will cover the **deployment, configuration, scalability, and management** of Qumulo on AWS. You will gain practical experience in deploying persistent and compute storage instances, managing multi-protocol access (**NFS, SMB, and S3**), leveraging analytics.  

This workshop can be deployed in a customer owned account or in the Workshop Studio environment.  

## **Supported AWS Regions**
This workshop is available in the following AWS regions:
- **us-west-2** (US West - Oregon)
- **us-east-2** (US East - Ohio)
- **us-east-1** (US East - N. Virginia)

## **What to Expect**  
- **Hands-on Learning**: Deploy and configure Qumulo on AWS using CloudFormation.  
- **Real-World Scenarios**: Learn best practices for **high availability (HA)**, **disaster recovery (DR)**, and **cloud data fabric (CDF) architectures**.  
- **Scalability & Automation**: Understand how to scale clusters dynamically and automate operations using APIs.  
- **Interactive Sessions**: Engage with experts and explore Qumulo’s capabilities in a cloud-native environment.  

## **Who Should Attend?**  
This workshop is designed for **storage administrators, cloud architects, DevOps engineers, and IT professionals** who want to:  
✔ Learn how to deploy and manage Qumulo on AWS  
✔ Optimize hybrid cloud workflows with **Cloud Data Fabric**  
✔ Integrate Qumulo with AWS-native services for storage and analytics  
✔ Improve data availability, resilience, and scalability in the cloud  

By the end of this session, you will have hands-on experience with **deploying, managing, and scaling Qumulo in AWS**, ensuring you’re equipped to harness the power of **cloud-native storage solutions**.  

## **Workshop Environment Diagram** 

The diagram below illustrates the environment that is deployed throughout the workshop.  Cloud Native Qumulo leverages many native AWS services to manage and scale the storage infrastructure.  The Linux workstation runs Terraform with the Qumulo deployment harness to deploy and scale Qumulo clusters.  All access to resources happens through AWS SSM for secure resource access.

![workshop architecture](/static/images/qumulo-workshop-diagram.png)

## **Estimated Workshop Cost**
This workshop is designed to be cost-effective. However, please note that running AWS resources may incur charges based on usage. The estimated cost for this workshop is approximately $48 per day ($1,433.25 per month), depending on the duration and the specific AWS services utilized.  In a production environment the customer will also incur metered usage for Qumulo software on top of the referenced AWS infrastructure charges.  

Please ** Cleanup your Environment ** to avoid excessive charges.  (10_cleanup.html)

A breakdown is as follows:

| Service | Description                                        | Monthly Cost |
|---------|----------------------------------------------------|-------------:|
| EC2     | Primary Qumulo Cluster EC2 (i4i.xlarge x 3)        | $751.17      |
| EC2     | Secondary Qumulo Cluster EC2 (i4i.xlarge x 1)      | $250.39      |
| EC2     | Windows Workstation (t3.xlarge)                    | $107.84      |
| EC2     | Linux Workstation (m5.large)                       | $70.08       |
| EC2     | Load Instances (t3.medium x 5)                     | $253.07      |
| S3      | Bucket Storage for 30 GB (test data)               | $0.70        |
|         | **Total Estimated Cost (Monthly)**                 | **$1,433.25** |

## **Prerequisites and suggested background knowledge**
The workshop is designed to guide participants with minimal enterprise storage and AWS experience.  However, general knowledge of Microsoft Windows and Linux operating systems is suggested.  

## **Estimated Workshop Duration**
This workshop takes approximately **3-4 hours** to complete, depending on your pace and depth of exploration.

## **Let's Get Started!**  
We’re excited to have you here. Let’s dive in and explore how Qumulo on AWS can help you **simplify data management, enhance performance, and achieve cloud agility at scale**.  

::alert[The examples and sample code provided in this workshop are intended to be consumed as instructional content. These will help you understand how various AWS services can be architected to build a solution while demonstrating best practices along the way. These examples are not intended for use in production environments.]{type="warning"}