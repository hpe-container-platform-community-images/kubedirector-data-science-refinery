# kubedirector-data-science-refinery

This application image is pre-alpha.

Step 1. Create ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dsr-config
  labels:
    kubedirector.hpe.com/cmType : dsr-config
data:
  dsr.properties: |
    MAPR_CLUSTER=hcp.mapr.cluster
    MAPR_CLDB_HOSTS=10.1.0.230
    MAPR_CONTAINER_USER=mapr
    MAPR_CONTAINER_GROUP=mapr
    MAPR_CONTAINER_UID=5000
    MAPR_CONTAINER_GID=5000
    # TODO: move MAPR_TICKET to a secret
    MAPR_TICKET=xxxxx
    MAPR_TICKETFILE_LOCATION=/tmp/longlived_ticket
    ZEPPELIN_DEPLOY_MODE=kubernetes
    MAPR_CONTAINER_PASSWORD=mapr
```

Step 2. ...


```console
kubectl apply -f https://raw.githubusercontent.com/hpe-container-platform-community-images/kubedirector-data-science-refinery/main/cr-app-dsr.json

kubectl apply -f https://raw.githubusercontent.com/hpe-container-platform-community-images/kubedirector-data-science-refinery/main/cr-cluster-dsr.yaml
```
