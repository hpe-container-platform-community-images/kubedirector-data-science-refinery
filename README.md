# kubedirector-data-science-refinery

This application image is pre-alpha.

### Step 1. Create KD Application

Login to the HPE Container Platform KD tenant

### Step 2. Create the KD Application (e.g. from a webterminal)

```console
kubectl apply -f https://raw.githubusercontent.com/hpe-container-platform-community-images/kubedirector-data-science-refinery/main/cr-app-dsr.json
```

### Step 3. Create ConfigMap with your details

(TODO: Future versions will move MAPR_TICKET to a secret)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dsr-config
  labels:
    kubedirector.hpe.com/cmType : dsr-config
data:
  dsr.properties: |
    #    
    # Edit the variables below
    #   
    MAPR_CLUSTER=hcp.mapr.cluster
    MAPR_TICKET=xxx_base64_encoded_xxx
    MAPR_CLDB_HOSTS=10.1.0.230
    #   
    # You shouldn't need to edit the variables below
    #   
    MAPR_CONTAINER_USER=mapr
    MAPR_CONTAINER_PASSWORD=mapr
    MAPR_CONTAINER_GROUP=mapr
    MAPR_CONTAINER_UID=5000
    MAPR_CONTAINER_GID=5000
    MAPR_TICKETFILE_LOCATION=/tmp/longlived_ticket
    ZEPPELIN_DEPLOY_MODE=kubernetes
```

IMPORTANT: Ensure the folder `/user/$MAPR_CONTAINER_USER` exists on the Data Fabric - by default it doesn't exist on the HPE Container Platform embedded Data Fabric.

### Step 4. Create the KD Cluster

```console
kubectl apply -f https://raw.githubusercontent.com/hpe-container-platform-community-images/kubedirector-data-science-refinery/main/cr-cluster-dsr.yaml
```

### Step 5. Access Zeppelin UI

You can click the link in the services endpoint to access the Zeppelin UI.  
If you receive a HTTP error try again in a few minutes.
