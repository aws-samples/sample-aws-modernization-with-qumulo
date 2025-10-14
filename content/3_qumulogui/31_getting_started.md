---
title: "Getting Started with the Qumulo GUI"
chapter: false
weight: 31
---

Before we explore the Qumulo interface, let's set up some realistic activity on your cluster and connect to the management console.

## Step 1: Initialize Cluster Load Testing

To make our GUI exploration more meaningful, we'll start some background activity on your cluster. This will populate the interface with real data and metrics.

1. **Connect to your Linux instance** using the connection method you established earlier
2. **Start the load testing script** by running the following command:

```bash
/home/ssm-user/qumulo-workshop/scripts/start-load-testing.sh start
```


You should see output confirming the load testing has begun:

![Start Load Testing](../images/qumulogui/31_03.png)

This script generates various types of file system activity including:
- File creation and deletion
- Directory operations  
- Read and write I/O patterns
- Mixed workload simulation

The load will continue running in the background, providing live data for us to observe in the GUI.

## Step 2: Access the Qumulo Management Interface

Now let's connect to your cluster's web interface:

1. **Connect to your Windows workshop workstation** using your preferred method (RDP, AWS Systems Manager, etc.)

2. **Open Google Chrome** from the desktop

3. **Navigate to your cluster** by clicking on **"Primary Qumulo"** under the Managed Bookmarks toolbar

![Qumulo Login Page](../images/qumulogui/31_01.png)

4. **Log in using the default credentials:**
   - **Username:** `admin`  
   - **Password:** `!Qumulo123`

![Qumulo Login Screen](../images/qumulogui/31_02.png)

5. **Click "Sign In"** to access the management interface

## What to Expect

Once successfully logged in, you'll be taken to the Qumulo dashboard where you can immediately begin exploring:

- **Live cluster metrics** populated by the load testing we just started
- **File system activity** showing real-time operations
- **Performance graphs** displaying current I/O patterns  
- **Capacity utilization** as files are being created and modified
- **Navigation menu** providing access to all administrative functions

## Troubleshooting Access

If you encounter issues connecting:

- **Verify network connectivity** from your Windows instance
- **Check the bookmark URL** points to `https://demopri.qumulo.local`
- **Accept any SSL certificate warnings** (expected for workshop environment)
- **Ensure your cluster is fully deployed** and operational

## Summary

✅ **Completed Steps:**

| Step | Action | Status |
|------|---------|--------|
| 1 | Started cluster load testing | ✅ |
| 2 | Opened Chrome browser | ✅ |  
| 3 | Navigated to Qumulo interface | ✅ |
| 4 | Logged in with admin credentials | ✅ |
| 5 | Ready to explore GUI | ✅ |

---

**Next:** Proceed to **Section 3.2 – Dashboard Overview** where we'll explore the main interface and understand what all those live metrics are telling us about your cluster.
