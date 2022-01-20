# dbgcputility
A set of tools and scripts designed for Databricks on GCP


# Scripts List:

1. Securing VPC Firewalls rules and egress traffice in a GCP deployment of Databricks
2. Check Databricks deployment requirements before deploying a workspace
3. Deploying Databricks on GCP using TF


# 1. Securing VPC

For this script to work you need to replace following variables in the script and run the script.

  **Google Project name**
  PROJECTNAME="XXXX"
  **VPCNAME**
  VPCNAME="databricks-managed-3303143836518795"
  REGION="australia-southeast1"
  Subnets="10.0.0.0/16,10.2.0.0/20,10.1.0.0/16"
  **Control plane address range**
  GKEmasterip="10.3.0.0/28"
  GKEmasterVPCName="gke-nee0fd77f783b0c63fc2-07a2-1013-net"
  **(Pick Correct pair of IPs from here: https://docs.gcp.databricks.com/administration-guide/cloud-configurations/gcp/firewall.html#control-plane-service-endpoint-ip-addresses-by-region)**
  **Databricks Regional SCC Service IP**
  DatabricksRegionalSCC_IP="35.244.79.84/32"
  **Databricks Managed Regional Hive**
  DatabricksManagedRegional_IP="34.151.73.114/32"
  DatabricksManagedRegional_PORT="tcp:3306"
  DatabricksRegionalSCC_RULE="tcp:443"
