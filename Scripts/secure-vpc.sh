#!/bin/bash

### Only if you have not init or you want to redo it per script

## gcloud init

gcloud debug targets list --quiet

## Google Project name
PROJECTNAME="XXXX"
## VPCNAME
VPCNAME="databricks-managed-3303143836518795"
REGION="australia-southeast1"
Subnets="10.0.0.0/16,10.2.0.0/20,10.1.0.0/16"
## Control plane address range	
GKEmasterip="10.3.0.0/28"
GKEmasterVPCName="gke-nee0fd77f783b0c63fc2-07a2-1013-net"
#### (Pick Correct pair of IPs from below table) ####
## Databricks Regional SCC Service IP
DatabricksRegionalSCC_IP="35.244.79.84/32"
## Databricks Managed Regional Hive
DatabricksManagedRegional_IP="34.151.73.114/32"

DatabricksManagedRegional_PORT="tcp:3306"
DatabricksRegionalSCC_RULE="tcp:443"


################### Databricks Control Plane Services Egress Endpoints #####################
# us-central1
# tcp:443 35.224.199.248/32
# tcp:3306 35.239.64.150
# us-east4
# tcp:443 34.86.176.48/32
# tcp:3306 35.245.195.96/32
# us-west1
# tcp:443 34.105.33.108/32
# tcp:3306 34.82.108.36/32
# us-west4
# tcp:443 34.125.31.85/32
# tcp:3306 34.125.124.68/32
# australia-southeast1
# tcp:443 35.244.79.84/32
# tcp:3306 34.151.73.114/32
# europe-west1
# tcp:443 146.148.117.238/32
# tcp:3306 34.76.244.202/32
# europe-west2
# tcp:443 34.105.148.92/32
# tcp:3306 35.242.155.96/32
# As new REGIONS go live new endpoints will be published. Please check latest endpoint information: https://docs.gcp.databricks.com/administration-guide/cloud-configurations/gcp/firewall.html#control-plane-service-endpoint-ip-addresses-by-region
################### ########################## ######################################


# 4. Lock down VPC with firewall rules and update VPC Route’s
## Allow traffic to Databricks primary(nodes), secondary1(pods) and secondary2(service) subnet’s.
gcloud compute firewall-rules create to-gke-nodes-subnet \
--action ALLOW \
--rules all \
--destination-ranges $Subnets \
--direction EGRESS \
--priority 1000 \
--network $VPCNAME

## Allow traffic to Databricks control plane SCC relay service IP
gcloud compute firewall-rules create to-databricks-control-plane-scc-service \
--action ALLOW \
--rules $DatabricksRegionalSCC_RULE \
--destination-ranges $DatabricksRegionalSCC_IP \
--direction EGRESS \
--priority 1000 \
--network $VPCNAME

## Allow traffic to Databricks Managed Hive Metastore
gcloud compute firewall-rules create to-databricks-managed-hive \
--action ALLOW \
--rules $DatabricksManagedRegional_PORT \
--destination-ranges $DatabricksManagedRegional_IP \
--direction EGRESS \
--priority 1000 \
--network $VPCNAME

## Allow traffic from the GKE worker-vpc (your vpc hosting Databricks workspace) to the GCP managed GKE-master-vpc
gcloud compute firewall-rules create to-gke-master \
--action ALLOW \
--rules tcp:443,tcp:10250 \
--destination-ranges $GKEmasterip  \
--direction EGRESS \
--priority 1000 \
--network $VPCNAME

## Allow traffic to the restricted Google APIs VIP (Virtual IP)
gcloud compute firewall-rules create to-google-apis \
--action ALLOW \
--rules all \
--destination-ranges 199.36.153.4/30 \
--direction EGRESS \
--priority 1000 \
--network $VPCNAME

## Allow ingress/egress to Google IP’s that perform health checks , these are fixed set of ip’s supplied by GCP
gcloud compute firewall-rules create to-gcp-healthcheck \
--action ALLOW \
--rules tcp:80,tcp:443 \
--destination-ranges 130.211.0.0/22,35.191.0.0/16 \
--direction EGRESS \
--priority 1101 \
--network $VPCNAME


gcloud compute firewall-rules create from-gcp-healthcheck \
--action ALLOW \
--rules tcp:80,tcp:443 \
--source-ranges 130.211.0.0/22,35.191.0.0/16 \
--direction INGRESS \
--priority 1102 \
--network $VPCNAME

## Deny egress to 0.0.0.0/0
gcloud compute firewall-rules create deny-egress \
--action DENY \
--rules all \
--destination-ranges 0.0.0.0/0 \
--direction EGRESS \
--priority 1100 \
--network $VPCNAME


## Step 5- Configure VPC Routes 

## Delete Default Route
ROUTE_NAME=$(gcloud compute routes list  --filter="DEST_RANGE=('0.0.0.0/0') AND  NETWORK:($VPCNAME)" --format="value(NAME)")
gcloud compute routes delete $ROUTE_NAME


## Create a route to send traffic to the restricted Google APIs
gcloud compute routes create route-to-google-apis \
--project=$PROJECTNAME \
--description="Route to Google restricted APIs" \
--network=$VPCNAME \
--priority=10 \
--destination-range=199.36.153.4/30 \
--next-hop-gateway=default-internet-gateway

## Create a route to send traffic to Databricks Control Plane

gcloud compute routes create route-to-databricks-scc-service \
--project=$PROJECTNAME \
--description="Route to Databricks SCC Service" \
--network=$VPCNAME \
--priority=10 \
--destination-range=$DatabricksRegionalSCC_IP \
--next-hop-gateway=default-internet-gateway

## Create a route to send traffic to Managed Metastore


gcloud compute routes create route-to-databricks-managed-hive \
--project=$PROJECTNAME --description="Route to Databricks managed hive" \
--network=$VPCNAME \
--priority=10 \
--destination-range=$DatabricksManagedRegional_IP \
--next-hop-gateway=default-internet-gateway


## 6. Configure Cloud DNS

## 6.1 GCS

gcloud dns managed-zones create google-apis \
--description "private zone for Google APIs" \
--dns-name googleapis.com \
--visibility private \
--networks $VPCNAME

gcloud dns record-sets transaction start --zone google-apis

gcloud dns record-sets transaction add restricted.googleapis.com. \
--name *.googleapis.com \
--ttl 300 \
--type CNAME \
--zone google-apis

gcloud dns record-sets transaction add "199.36.153.4" "199.36.153.5" "199.36.153.6" "199.36.153.7" \
--name restricted.googleapis.com \
--ttl 300 \
--type A \
--zone google-apis
gcloud dns record-sets transaction execute --zone google-apis


## 6.2 GCR.io

gcloud dns managed-zones create gcr-io \
--description "private zone for GCR.io" \
--dns-name gcr.io \
--visibility private \
--networks $VPCNAME

gcloud dns record-sets transaction start --zone gcr-io

gcloud dns record-sets transaction add gcr.io. \
--name *.gcr.io \
--ttl 300 \
--type CNAME \
--zone gcr-io

gcloud dns record-sets transaction add "199.36.153.4" "199.36.153.5" "199.36.153.6" "199.36.153.7" \
--name gcr.io \
--ttl 300 \
--type A \
--zone gcr-io
gcloud dns record-sets transaction execute --zone gcr-io
