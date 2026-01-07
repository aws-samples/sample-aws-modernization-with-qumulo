---
title: "Persistent Storage Deployment"
chapter: true
weight: 22
---

## **Learning Objective**
By the end of this section, you will:
- Comprehend the role of persistent storage in CNQ architecture and gain hands-on experience deploying the storage layer using Terraform configurations, understanding how this foundation supports data durability and cluster operations.

---

## **Overview**

Cloud Native Qumulo's **persistent storage deployment** creates the foundational S3 bucket infrastructure that stores your file system data. This deployment is **separate from the compute infrastructure**, enabling you to scale storage and compute independently while maintaining data persistence across cluster operations.

The persistent storage layer consists of multiple S3 buckets distributed across availability zones, providing the durability and performance foundation for your Qumulo cluster.

## **Exploring the Persistent Storage Configuration**

### **Terraform Directory Structure**

Navigate to your workshop environment and examine the persistent storage configuration:

```
cd /home/ssm-user/qumulo-workshop/terraform_deployment_primary_saz/persistent-storage
ls -la
```

You'll see the key files that define your persistent storage deployment:

- **`terraform.tfvars`** - Contains all the configuration values for your storage deployment
- **`provider.tf`** - Defines the Terraform providers and backend configuration
- **`main.tf`** - Contains the resource definitions (pre-configured)
- **`variables.tf`** - Defines input variables (pre-configured)
- **`outputs.tf`** - Defines what information to export after deployment

### **Examining terraform.tfvars**

The `terraform.tfvars` file contains the specific configuration for your persistent storage deployment. Open this file to explore the key settings:

```
cat terraform.tfvars
```

**Key Configuration Parameters:**

- **`deployment_name`** - Unique identifier for this storage deployment
- **`aws_region`** - AWS region where storage will be created
- **`soft_capacity_limit`** - This is a capacity clamp on the deployed Qumulo cluster, this can be increased in the future, default is 500TB
- **`prevent_destroy`** - Protection setting for storage buckets, this is set to false in this workshop, however in production and by default this should be set to true
- **`tags`** - Resource tagging for organization and cost tracking - there are examples in this workshop, all resources will be tagged with this information

::alert[**Workshop Insight**: Notice how the deployment name creates a unique identifier that will be referenced by the compute infrastructure. This separation allows the compute configurations to be managed (and scaled) independently of the persistent storage configuration.]

![storage terraform.tfvars](/static/images/deployment/22_01.png)

---

## **AWS Console: Exploring Created S3 Buckets**

After the persistent storage deployment completes, multiple S3 buckets are created with multiple prefixes to create paralellism and increase performance, to store your file system data, across multiple objects. Let's explore these in the AWS Console.

### **Accessing S3 in the AWS Console**

1. **Open the AWS Console** in your browser
2. **Navigate to S3** service
3. **Search for buckets** containing your deployment name

![storage s3 buckets](/static/images/deployment/22_02.png)

### **Understanding Bucket Architecture**

Your Qumulo persistent storage creates **multiple buckets** for optimal performance:

- **Bucket Naming Convention**: Each bucket includes your deployment unique name
- **Distribution Strategy**: Buckets are deployed in the specified region and accessible across all region availability zones
- **Performance Optimization**: Multiple buckets enable parallel I/O operations

**Key Observations:**

- **Bucket Count**: Starts with 16, but will scale depending on the capacity clamp set
- **Naming Pattern**: Includes deployment identifier and sequential numbering
- **Versioning**: Disabled
- **Encryption**: Server-side encryption enabled by default
- **Tags**: These match the tags set in the tfvars file

![storage s3 bucket details](/static/images/deployment/22_03.png)

::alert[**Important**: These S3 buckets contain the actual file system data. They persist independently of the compute infrastructure, enabling cluster replacement and scaling operations without data loss.]

---

## **AWS Console: SSM Parameters for Storage Configuration**

The persistent storage deployment creates **Systems Manager (SSM) parameters** that store configuration information for use by the compute infrastructure.

### **Accessing SSM Parameter Store**

1. **Navigate to Systems Manager** in the AWS Console
2. **Select Parameter Store** from the left navigation
3. **Filter parameters** by your deployment unique name ```/qumulo/qum-wks-cls-pri```

![storage SSM parameter store](/static/images/deployment/22_04.png)

### **Key Storage Parameters Created**

The persistent storage deployment creates several critical parameters:

**Storage Configuration Parameters:**
- **Storage bucket names** - List of all created S3 buckets
- **Deployment unique name** - Identifier linking storage to compute
- **Storage configuration** - Technical settings for bucket access
- **Encryption keys** - KMS key information for data encryption

![storage SSM parameter store detail](/static/images/deployment/22_05.png)

### **Parameter Usage Pattern**

These parameters follow a specific naming convention:

```
/qumulo/{storage-deployment-name}{unique-identifier}/{parameter-name}
```

**How Compute Uses These Parameters:**
- **Bucket Discovery**: Compute infrastructure reads bucket names from parameters
- **Configuration Consistency**: Ensures compute and storage configurations match
- **Security**: Encryption keys and access patterns stored securely

::alert[**Workshop Note**: These parameters are automatically created and managed by Terraform. Manual modification can break the connection between storage and compute infrastructure.]{type="warning"}

---

## **Terraform State and Outputs**

### **Understanding Terraform State**

The persistent storage deployment creates a **local Terraform state file** that tracks the created resources, in a customer deployment it is recommended to use S3 state file storage:

```
# View the state file (if curious)
ls -la terraform.tfstate*

# View deployment outputs
terraform output
```

![storage terraform output results](/static/images/deployment/22_06.png)

### **Key Outputs from Storage Deployment**

The storage deployment provides several important outputs:

- **`bucket_names`** - List of all created S3 buckets
- **`deployment_unique_name`** - Unique identifier for this deployment
- **`prevent_destroy`** - Current protection setting
- **`soft_capacity_limit`** - Storage capacity configuration

These outputs are consumed by the compute infrastructure to establish the connection between storage and compute layers.

---

## **Storage Deployment Verification**

### **Confirming Successful Deployment**

Verify your persistent storage deployment by checking:

1. **S3 Buckets Created**: Multiple buckets with your deployment name
2. **SSM Parameters Populated**: Configuration parameters available
3. **Terraform State**: Clean state with no errors
4. **Outputs Available**: All expected outputs present

### **Next Steps**

With persistent storage successfully deployed and explored, you're ready to:

- **Deploy compute infrastructure** that will connect to this storage
- **Understand the separation** between storage and compute layers
- **Explore cluster operations** that leverage this persistent foundation

The persistent storage layer now provides the durable foundation for your Qumulo cluster, ready to support the compute infrastructure that will provide file system services.

::alert[**Workshop Advantage**: This pre-deployed storage demonstrates how CNQ's architecture enables flexible compute scaling while maintaining data persistence - a key advantage over traditional storage systems.]