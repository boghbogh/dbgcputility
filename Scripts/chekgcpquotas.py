####### Databricks Required Cloud Resources on GCP #########
### https://docs.gcp.databricks.com/administration-guide/account-settings-gcp/quotas.html


from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient import discovery
import pprint
import json


##### Replace PROJECT ID HERE
project = 'projects/mahdi-sa-permissiontest'

def checkEnabledAPIs():
        try:

            ##### AUTHENTICATE FIRST USING THIS:
            ###gcloud auth application-default login
            print("------ENABLED APIS -------")           
            service = discovery.build('serviceusage', 'v1')
            request = service.services().list(pageSize=200,parent=project)                        
            response = ''        
            response = request.execute() 
            token = response.get('nextPageToken', None)           
            services = response.get('services')
            counter=1
            for index in range(len(services)):            
                item = services[index]
                name = item['config']['name']
                state = item['state']
                if state=="ENABLED":
                    print("%i %-100s %s" % (counter,name, state))
                    counter=counter+1

            while token!=None:
                request = service.services().list(pageSize=200,parent=project,pageToken=token)                        
                response = ''        
                response = request.execute()
                token = response.get('nextPageToken', None)
                services = response.get('services')
                for index in range(len(services)):            
                    item = services[index]
                    name = item['config']['name']
                    state = item['state']
                    if state=="ENABLED":
                        print("%i %-100s %s" % (counter,name, state))
                        counter=counter+1


        except HttpError as err:
            print(err)


def get_all_consumer_quota_metrics(service_name):
                
        parent = "{}/services/{}".format(project,service_name)
        service = discovery.build(
            "serviceusage",
            "v1beta1",         
            cache_discovery=False,
        )
        f = open("./output.txt",'w')
        result=service.services().consumerQuotaMetrics().list(parent=parent,pageSize=200).execute()
        token = result.get('nextPageToken', None)
        
        print(result,file=f) 
        

def checkServiceQuotas(serviceName,QuotaName,LimitString):
    ###gcloud auth application-default login    
    service = discovery.build(
            "serviceusage",
            "v1beta1",         
            cache_discovery=False,
        )
    serviceNameMetric=project+"/services/"+serviceName+"/consumerQuotaMetrics/"+serviceName+QuotaName+"/limits/"+LimitString
    request = service.services().consumerQuotaMetrics().limits().get(name=serviceNameMetric)  
    
    return request.execute()
    ##pprint.pprint(response)

def parsecomputeRegional(result,metric):
    print("------"+metric+" -------")
    for i in result:
        if i=="quotaBuckets":
            print("Effective Limit - Region (If Applicable)")
            for j in result[i]:                
                if "dimensions" in j:
                    print(j["effectiveLimit"],j["dimensions"]["region"])
                else:
                    print(j["effectiveLimit"],"Default- No Region")

def parseGenericMetrics(result,metric):    
    print("------"+metric+"-------")
    for i in result:
        if i=="quotaBuckets":
            print("Effective Limit - Region (If Applicable)")
            for j in result[i]:                                
                    print(j["effectiveLimit"])


def main():
    checkEnabledAPIs()
    
    result=checkServiceQuotas("compute.googleapis.com","%2Fcpus","%2Fproject%2Fregion")
    parsecomputeRegional(result,"CPU")

    result=checkServiceQuotas("compute.googleapis.com","%2Froutes","%2Fproject")
    parseGenericMetrics(result, "ROUTES")

    result=checkServiceQuotas("compute.googleapis.com","%2Fsubnetworks","%2Fproject")
    parseGenericMetrics(result, "SUBNETWORKS")
    
    result=checkServiceQuotas("compute.googleapis.com","%2Fregional_in_use_addresses","%2Fproject%2Fregion")
    parsecomputeRegional(result,"REGIONAL IN USE ADDRESS")

    result=checkServiceQuotas("compute.googleapis.com","%2Fregional_instance_group_managers","%2Fproject%2Fregion")
    parsecomputeRegional(result,"REGIONAL INSTANCE GROUP MANAGERS")

    result=checkServiceQuotas("compute.googleapis.com","%2Finstance_groups","%2Fproject%2Fregion")
    parsecomputeRegional(result,"INSTANCE GROUPS")

    result=checkServiceQuotas("compute.googleapis.com","%2Fdisks_total_storage","%2Fproject%2Fregion")
    parsecomputeRegional(result,"TOTAL STORAGE")

    result=checkServiceQuotas("compute.googleapis.com","%2Fn2_cpus","%2Fproject%2Fregion")
    parsecomputeRegional(result,"N2 CPU")

    result=checkServiceQuotas("compute.googleapis.com","%2Fssd_total_storage","%2Fproject%2Fregion")
    parsecomputeRegional(result,"SSD TOTAL STORAGE")
    
    result=checkServiceQuotas("monitoring.googleapis.com","%2Fingestion_requests","%2Fmin%2Fproject")
    parseGenericMetrics(result,"Cloud Monitoring API - Ingestion RequestE")

    result=checkServiceQuotas("iam.googleapis.com","%2Fquota%2Fservice-account-count","%2Fproject")
    parseGenericMetrics(result,"IAM API - Service Account Count")

if __name__ == '__main__':
    main()