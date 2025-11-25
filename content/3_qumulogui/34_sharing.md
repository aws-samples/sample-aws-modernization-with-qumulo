---
title: "Sharing Management"
chapter: false
weight: 34
---

The Sharing section provides unified management of how your Qumulo cluster exposes data to clients through different protocols. Here you'll explore quotas, NFS exports, SMB shares, and S3 buckets to understand the multi-protocol access capabilities.

## Available Sharing Options

The Sharing menu includes these key components:

![Sharing Menu](/static/images/qumulogui/34_01.png)

- **Quotas** - Enforce storage limits on directories
- **NFS Exports** - POSIX-compliant file access for Linux/Unix clients
- **SMB Shares** - Windows file sharing with Active Directory integration
- **S3 Buckets** - Object storage access via S3 API

## Workshop Exercise: Create an SMB Share

Let's create an SMB share for the `/userdata` directory that we'll use in later workshop sections:

### Step 1: Navigate to SMB Shares
1. Click **Sharing** → **SMB Shares**
2. Click **"Create SMB Share"**

### Step 2: Configure the Share
Fill out the share configuration:

- **File System Path**: `/userdata`
- **Share Name**: `userdata`
- **Description**: `Workshop user data directory`
- **Share Options**:
  - ☑ Enable access-based enumeration
  - ☐ Require encryption (leave unchecked for workshop)

### Step 3: Set Permissions
- **Share Permissions**: Leave as default (Everyone - Full Control) for workshop purposes
- Click **Create Share**

![SMB Share](/static/images/qumulogui/34_03.png)

::alert[**Workshop Note:** We're using simplified permissions for workshop purposes. In production environments, you should implement proper access controls and consider requiring encryption.]
## Directory Quotas Overview

Quotas help manage storage consumption by setting limits on directories:

![Quota Creation](/static/images/qumulogui/34_02.png)

**Quota Features:**
- Set storage limits on any directory path
- Balance between hard and soft quota enforcement
- Directory becomes read-only when quota is reached
- Integrated with cluster alerting system

**Management Options:**
- **Create**: Set new quotas with custom limits
- **Modify**: Update existing quota limits via Actions column
- **Delete**: Remove quotas using the trash icon

## NFS Exports Overview

NFS exports enable POSIX-compliant access for Linux and Unix clients:

![NFS Export Interface](/static/images/qumulogui/34_05.png)

**Key Capabilities:**
- **Export any directory** as an NFS mount point
- **Host access rules** control client permissions
- **NFSv3 and v4 protocol** support with standard POSIX semantics
- **Rule ordering** matters - specific rules should be listed first

## S3 Bucket Overview

S3 buckets provide object storage access to filesystem directories:

**Configuration Requirements:**
- S3 server must be enabled in **Cluster** → **Protocols** → **S3 Settings**
- Each bucket maps to a specific filesystem directory
- Access controlled through S3 tokens and IAM-style permissions

**Features Available:**
- Object versioning support
- Object lock capabilities
- Integration with S3-compatible tools and applications
- Cross-protocol access (files accessible via both S3 and filesystem)

## Multi-Protocol Architecture

Qumulo's unified storage supports simultaneous access:

- **Cross-protocol permissions** maintain security across all access methods
- **Identity mapping** ensures consistent user authentication
- **File locking** coordinates access between SMB and NFS clients
- **Real-time consistency** across all protocols

## Exploration Exercise

Take a few minutes to explore each section:

1. **Browse existing quotas** - See what storage limits might be in place
2. **Review NFS exports** - Observe any existing filesystem exports
3. **Check S3 bucket configuration** - Understand object storage setup
4. **Verify your SMB share** - Confirm the `/userdata` share was created successfully

---

✅ **Workshop Checkpoint:** You should now have an SMB share for `/userdata` that we'll use in upcoming sections, and understand the multi-protocol sharing capabilities available in Qumulo.

---

**Next:** Proceed to **Section 3.5 – Cluster Administration** where we'll explore system configuration and management tools.
