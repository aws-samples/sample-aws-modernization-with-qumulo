---
title: "Cloud Data Fabric (CDF)"
chapter: true
weight: 6
---

## **Cloud Data Fabric (CDF) Overview**
Qumulo Cloud Data Fabric (CDF) provides a unified, global file system that spans edge, core data center, and cloud environments. CDF enables organizations to share, access, and manage unstructured data seamlessly across locations with real-time collaboration, strict consistency, and minimal data movement.

CDF uses a **hub-and-spoke architecture**:
- **Hub:** Central Qumulo cluster hosting source data.
- **Spoke:** Remote Qumulo clusters accessing shared data.
- **Portal:** Directory-level links that control which data is shared.

CDF synchronizes **metadata instantly** while transferring **file data blocks** only when needed. Advanced caching (NeuralCache) serves most read requests locally, ensuring excellent performance and efficient WAN usage.

## **Key Takeaways**
- **Global Data Accessibility:** Share and access data everywhere with guaranteed consistency.
- **Metadata First:** Directory structure and file details appear immediately; blocks of data transfer only on demand.
- **Intelligent Caching:** NeuralCache predicts and prefetches frequently used data for fast access.
- **Bidirectional Sync:** Changes at any endpoint are synchronized and reflected instantly.

---

## **Hands-On Steps**



### **Step 1: Connect to Secondary Cluster and Create Data Directory with Test Data**

Connect your Windows desktop SMB to the userdata share with admin privileges

```
net use \\demopri.qumulo.local\userdata /delete /y
net use \\demosec.qumulo.local\userdata /delete /y
net use \\demopri.qumulo.local\userdata /user:admin !Qumulo123
net use \\demosec.qumulo.local\userdata /user:admin !Qumulo123
```

Use this PowerShell script to create some sample content:

```
$basePath = "\\demopri.qumulo.local\userdata\GlobalData"
New-Item -Path "$basePath" -ItemType Directory
# Use the .NET RandomNumberGenerator class for cryptographically strong randomness
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$fs = [System.IO.File]::OpenWrite("$basePath\BigRandomTestFile.bin")

for ($i = 0; $i -lt 50; $i++) {
    $bytes = New-Object byte[] 1MB
    $rng.GetBytes($bytes)
    $fs.Write($bytes, 0, $bytes.Length)
}

$fs.Close()
$rng.Dispose()
for ($i=1; $i -le 9; $i++) {
"This is sample file $i" | Out-File "$basePath\TestFile$i.txt"
}
# This generates 10,000 lines in one write
$string = ("This is a demo line with readable content.`r`n" * 10000)
# Repeat 20 times for a large file (~1MB each, adjust for size)
for ($i=1; $i -le 30; $i++) {
    $string | Out-File -FilePath "$basePath\BigTestFile.txt" -Append
}
```

---

### **Step 2: Establish Portal Relationships Using qq Commands**

From your Linux instance, run the following bash script to set up a read / write portal to link `/userdata/GlobalData` between your primary (`demopri`) and secondary (`demosec`) clusters:

```
export PATH="$HOME/.local/bin:$PATH"
# Resolve IP addresses for demopri and demosec clusters
demopri_ip=$(nslookup demopri.qumulo.local | awk '/^Address: / {print $2}' | tail -n1)
demosec_ip=$(nslookup demosec.qumulo.local | awk '/^Address: / {print $2}' | tail -n1)

echo "Primary (Hub) Cluster IP: "$demopri_ip
echo "Secondary (Spoke) Cluster IP: "$demosec_ip

# Log into spoke cluster
qq --host demosec.qumulo.local login --u admin --p '!Qumulo123'

# Create portal request from spoke to hub
qq --host demosec.qumulo.local portal_create --hub-address $demopri_ip --hub-root /userdata/GlobalData --spoke-root /userdata/GlobalData

# Log into hub cluster
qq --host demopri.qumulo.local login --u admin --p '!Qumulo123'

# Authorize the hub portal request (typically ID 1 for the first portal)
qq --host demopri.qumulo.local portal_accept_hub -i 1 --authorize-hub-roots --spoke-address $demosec_ip
```

---

### **Step 3: Examine Directory Structure on Spoke**

Access the spoke:  
`\\demosec.qumulo.local\userdata\GlobalData`

- List files and folders (structure and metadata should appear immediately).
- Check "size on disk": most files will show negligible usage, as only metadata is transferred until files are read.

---

### **Step 4: Read Files from Spoke and Demonstrate Caching**

- Open `BigTestFile.txt` on the spoke using Notepad (or any text editor).
    - **First access:** File data transfers block-by-block from the hub (may be slower).
    - **Subsequent access:** File is served from local cache (much faster).

---

### **Step 5: Write New Data to Hub and Verify on Spoke**

Create a new data on the hub, then verify immediate presence on the spoke:

```
$basePath = "\\demopri.qumulo.local\userdata\GlobalData\HubAdds"
New-Item -Path "$basePath" -ItemType Directory
# Use the .NET RandomNumberGenerator class for cryptographically strong randomness
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$fs = [System.IO.File]::OpenWrite("$basePath\BigRandomTestFile.bin")

for ($i = 0; $i -lt 50; $i++) {
    $bytes = New-Object byte[] 1MB
    $rng.GetBytes($bytes)
    $fs.Write($bytes, 0, $bytes.Length)
}

$fs.Close()
$rng.Dispose()
for ($i=1; $i -le 9; $i++) {
"This is sample file $i" | Out-File "$basePath\TestFile$i.txt"
}
# This generates 10,000 lines in one write
$string = ("This is a demo line with readable content.`r`n" * 10000)
# Repeat 20 times for a large file (~1MB each, adjust for size)
for ($i=1; $i -le 30; $i++) {
    $string | Out-File -FilePath "$basePath\BigTestFile.txt" -Append
}
```


Check for new data on the spoke that was created in the hub.  Notice the size on disk of this new data.  
`\\demopri.qumulo.local\userdata\GlobalData\HubAdds`

### **Step 6: Write New Data to Spoke and Verify on Hub**

Create some new data on the Spoke and check presence on the Hub:

```
$basePath = "\\demosec.qumulo.local\userdata\GlobalData\SpokeAdds"
New-Item -Path "$basePath" -ItemType Directory
# Use the .NET RandomNumberGenerator class for cryptographically strong randomness
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$fs = [System.IO.File]::OpenWrite("$basePath\BigRandomTestFile.bin")

for ($i = 0; $i -lt 50; $i++) {
    $bytes = New-Object byte[] 1MB
    $rng.GetBytes($bytes)
    $fs.Write($bytes, 0, $bytes.Length)
}

$fs.Close()
$rng.Dispose()
for ($i=1; $i -le 9; $i++) {
"This is sample file $i" | Out-File "$basePath\TestFile$i.txt"
}
# This generates 10,000 lines in one write
$string = ("This is a demo line with readable content.`r`n" * 10000)
# Repeat 20 times for a large file (~1MB each, adjust for size)
for ($i=1; $i -le 30; $i++) {
    $string | Out-File -FilePath "$basePath\BigTestFile.txt" -Append
}
```

Check for this data on the hub which was written to the spoke.  Notice the size of this data on the hub. 

`\\demopri.qumulo.local\userdata\GlobalData\SpokeAdds`

---

## Next step

Proceed to **Section 10.0 – Resource Cleanup** to end the workshop and cleanup the environment.

::alert[The examples, scripts, and sample code provided in this workshop are intended for instructional use in a controlled environment. For production deployments, always consult your Qumulo or AWS account teams for recommended practices and cluster provisioning.]{type="warning"}
