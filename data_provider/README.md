# CUSTOM DATA PROVIDERS
This directory contains custom data providers for PW clusters. 

## REQUIREMENTS:
1. PWRSyncStaging requires ssh access to the user container from the controller node of the cluster
2. PWGsutil needs the cluster to be authenticated to run the gsutil command. See authentication section for more information


## Authentication:
### PWGsutil
The recommended approach to authenticate this provider is described in the steps below:
1. Create a service account on GCP with only access to the required GCP bucket(s)
2. Copy the service account JSON key file to a persistent directory in the cluster such as /contrib/<USER>/service_accounts/my-bucket.json
3. Add the following command to the "User Bootstrap" section of the resource definition tab: `gcloud auth activate-service-account --key-file=/contrib/<USER>/service_accounts/my-bucket.json`

Note that when the controller node is authenticated the compute nodes are also authenticated.

### PWS3
Add the AWS credentials for the bucket to the "User Bootstrap" section of the resource definition tab:
```
echo "export AWS_REGION=us-east-1" >> ~/.bashrc
echo "export AWS_ACCESS_KEY_ID=<AWS_ACCESS_KEY_ID>" >> ~/.bashrc 
echo "export AWS_SECRET_ACCESS_KEY=<AWS_SECRET_ACCESS_KEY>" >> ~/.bashrc 
echo "export AWS_SESSION_TOKEN=<AWS_SESSION_TOKEN>" >> ~/.bashrc
```

