---
title: "Create Secondary (DR) Qumulo Cluster"
weight: 51
---

Section 5’s labs use **a separate, single-node Qumulo cluster** to simulate a remote site for disaster-recovery exercises.  
You will build that cluster with two helper scripts that ship with the workshop VM.

> **Why a single node?**  
> Cloud Native Qumulo can start with just one instance in AWS, allowing you to test replication and recovery workflows without the cost of a full multi-node cluster. You can later scale out by adding more nodes via Terraform or the Qumulo UI.

---

## Generate Terraform config

```
cd /home/ssm-user/qumulo-workshop/scripts
./secondary-qumulo-cluster-tf-configuration.sh
```

![create single cluster config](../images/haanddr/51_01.png)

This utility:

* Creates a new directory `~/qumulo-workshop/terraform_deployment_secondary`
* Pre-populates two **`terraform.tfvars`** files  
  * **persistent_storage.tfvars** – points to the shared S3 state bucket used by the workshop  
  * **compute.tfvars** – sets parameters for a *single* Qumulo node (instance type, EBS layout, AZ, etc.)

Inspect `compute.tfvars` if you are curious; note the variable `node_count = 1` that enables a one-node deployment.

![node count 1](../images/haanddr/51_02.png)

---

## Deploy the cluster

```
cd /home/ssm-user/qumulo-workshop/scripts
./deploy-qumulo-cluster.sh /home/ssm-user/qumulo-workshop/terraform_deployment_secondary "Secondary Workshop Qumulo One Node Instance"
```


The script runs `terraform init/plan/apply` and typically completes in **8-10 minutes**.  
When it finishes, a single EC2 instance boots and automatically forms a Qumulo cluster.


---

## Access the cluster

* **Windows Workstation** – open Chrome and click the bookmark **“Secondary Qumulo GUI”** (URL `https://demosec.qumulo.local`).  
  The default admin credentials are:

  | User | Password |
  |------|----------|
  | `admin` | `!Qumulo123` |

* **DNS note** – the private Route 53 zone `qumulo.local` is pre-configured in your lab account, so both Linux and Windows hosts resolve `demosec.qumulo.local` automatically.

---

## Quick tour of the `qq` CLI

The workshop Linux instance already has the Qumulo command-line tool **`qq`** installed and in `$PATH`.

### Log in to the primary cluster

```
qq --host demopri.qumulo.local login --u admin --p '!Qumulo123'
qq --host demopri.qumulo.local nodes_list
```

![primary cluster node list](../images/haanddr/51_04.png)

The second command returns the node table for the primary (multi-node) cluster.

### Log in to the new secondary cluster

```
qq --host demosec.qumulo.local login --u admin --p '!Qumulo123'
qq --host demosec.qumulo.local nodes_list
```

![secondary cluster node list](../images/haanddr/51_05.png)

You should see **exactly one node** in the output, confirming the single-node deployment.

---

## Next step

Proceed to **Section 5.2 – Snapshot Management** where you will create snapshots on both clusters and begin configuring replication.

---
