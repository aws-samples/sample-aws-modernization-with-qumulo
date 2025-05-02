---
title: "Deploying CNQ on AWS" 
chapter: true
weight: 4
---


# **Deploying CNQ on AWS**


## **Section1**  
Section1

YAML:
!(/infrastructure/aws-vpc.cft.yaml)

Open Shell:

aws ec2 create-key-pair --key-name qumulo-keypair --query 'KeyMaterial'  --output text > qumulo-keypair.pem
chmod 400 qumulo-keypair.pem


https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/quickcreate?templateUrl=https://qumuloawsworkshop.s3.us-east-1.amazonaws.com/aws-vpc.cft.yaml?response-content-disposition=inline&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEML%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLWVhc3QtMSJHMEUCIF9%2FPLJX1j3Msj2HYN4TzLdEjtM6cGiJqYpDRuubDRveAiEAs0M7qg7tz5gcmDdR9%2FNWeJ%2BU5HjWRiZuNTNHftv5fZwqvwQISxAEGgwwMjY4NDcwMjI0OTMiDAbWSotDPQdFzoLCryqcBP6FMUml5L%2F%2BaiNFEmxBehXFwuEnd8ma5GcDHLfwCpnaChx2Hv21kh3IzgIo9LrcuvOC9miTggCfBkj6dIT%2Fv3KCBRZqp7IuNAQV3tLdlPT0yJUafecIToBmKBsRnF5AM9bqmDLy52IYUk%2FfmREV0gBCrS56lrEUaJEuiqQCdk1LXT7wESBgWpSD8YWKSasyIbGBGbr4yYV%2FZ0vmgaPocpVVN73la3feQ08uTWEXxHm0Fv7tQJUTukZx3YtbGg%2BnAcIxRPKOfwVqPCADsM55LoVTiAJ70uRfHX%2FrhcF4dadfMfq7uH%2Bt4%2FovzBExa5BMHGnFApKW0B1m2%2F163CuI8JKOTutZy4GhbxsEEZpDy%2BIMMnL5ABz1Su4kM%2FGoZdlzuO98OSJm5%2FzFGDWIsq8BYNRouTNP2BQlMUtr085CfOednthOEsEsy7oB6Z462ZfpCJkmNLlUdP%2FO5lzVvPPerdmP0d2RT8vW05DMmSU8xKBklY7Dkx5dJazCdMceYm8OXM%2BG5Sky%2B5wd5Nna%2BNKVexAZEbqVDgAqRrCDOAF94EHHAdWUv%2BLENBfGJ7C4krM677UmypJkdw04FjzSmRuXAW%2F%2F90DjDmoFmdG%2BFTZ81CbWZFfZLDffDMe%2F%2Fy%2B6rBB4aF2xuePlnKw9mih7tfC9B2Kr%2BSajZ7dtP9Elu9IkbFSQszOhbNLsdXqaE%2BPdJMFLh8bDZidAC8yy6PWx%2BTCQzf6%2FBjrFAkB7nkBhLCj6owkhmG1CK3RiomzRTWxZ%2Fqy3c%2BNnBVP8bKSHJLEUrz%2ByYB2D8NK%2FHEr28b8pDNeOLD9msJbZMtjlOs629nCU1zu149DvpHEdPSp3lX9XQ7PhygYWBn%2Bs1z%2BvT72dBsj48TAsu6kBBxllTSGHGeIcoDGggQCxuNYK413pIleSDsx0upPi0mHXbZ1Kqo%2Bo9rT0RlmWs1d9qbqSMBYHUiXDDj7Dh5im46BjndL50XxzD6YRo9htHttP5ggVdmraZMz7BXSBFCxVmhBkUanWqKiIVBWc4ak1lWkLIGx29TT7puAwrSMRxTLl5q4cZNH5fz%2B0AeqeQXh0C5GslcDu5s%2Fp98xLJ7FpoLqNciQZJdKC79Fhr4%2BSX4e6PbGJqpF%2FmTD%2FCMPdQyRSzQ0tMBNsxWNhN%2FpFJUdQss0wsTtOOdU%3D&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=ASIAQMQBVBWOSCXH6FAX%2F20250416%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20250416T172705Z&X-Amz-Expires=43200&X-Amz-SignedHeaders=host&X-Amz-Signature=6646c3b884c865c70bd675d23cf9c32f69219e535ad872ef6711596e7c68b7e4&stackName=qumulo-workshop

ssh -i qumulo-pair.pem ec2user@IP





---

## **Key Takeaways**  
By the end of this module, you will:  

- Takeaways
---

## **Topics Covered**  
### **Covered**  
- Covered

### **Next Steps**  
Next steps


