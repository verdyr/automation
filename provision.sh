
## arguments to the script: namespace in k8s, backend name as an image name in docker repo, application name as a name in docker repo

k8s_namespace=$3

backend=$2

application=$1

kubectl create namespace $k8s_namespace


ip=`ifconfig -a | grep eth0 -A 1 | grep inet | awk '{print $2}'`
#storage class
cp storage_class.yaml /tmp
sed -i s#changeme#$ip#g /tmp/storage_class.yaml
kubectl create -f /tmp/storage_class.yaml

# DB backend provision
maprticket=`cat /opt/mapr/conf/mapruserticket`
base64_encoded=`echo -n $maprticket | base64 -w 0`
/usr/bin/cp secrets.yaml /tmp
sed -i s#^\ \ CONTAINER_TICKET:.*#\ \ CONTAINER_TICKET:\ $base64_encoded#g /tmp/secrets.yaml
kubectl create -f /tmp/secrets.yaml
sleep 10
kubectl create -f ${backend}-pvc.yaml
sleep 10 
kubectl create -f ${backend}-deploy.yaml

while true;
do
output=`kubectl get pod -n $k8s_namespace | grep $backend | grep Running | wc -l`
if [[ $output -eq 0 ]]; then
 echo "Waiting for backend container to become available"
 sleep 2
else
 break
fi
done

# Execute configuration in the back end - TO be added
kubectl exec -n $k8s_namespace `kubectl get pod -n $k8s_namespace | grep $backend | awk '{print $1}'` $backend_configs_init

# Deploy application container
backendIP=`kubectl get pod -n $k8s_namespace -o wide | grep $backend | awk '{print $6}'`
/usr/bin/cp $(application)-deploy.yaml /tmp
sed -i s#backendIP#$backendIP#g /tmp/${application}-deploy.yaml
kubectl create -f ${application}-pvc.yaml
sleep 5
kubectl create -f /tmp/${application}-deploy.yaml

# Deploy Monitoring and dashboard
kubectl create -f grafana-deploy.yaml
kubectl create -f grafana-svc.yaml
while true;
do
output=`kubectl get svc -n $k8s_namespace -o wide | grep grafana-svc |grep pending | wc -l`
if [[ $output -eq 1 ]]; then
 sleep 5
 t=`date`
 echo "$t Waiting for load balancer to become available ...."
else
 sleep 20 
 sh config-grafana ${application_dashboard}.json
 echo "Configuring Grafana..."
 sleep 10 
 ip=`kubectl get svc -n $k8s_namespace -o wide| grep grafana-svc | awk '{print $4}'`

 while true;
 do
  out=`host $ip | grep "has address" | wc -l`
  if [[ $out -eq 0 ]]; then
    echo "Waiting for Application to be ready ...."
    sleep 2 
  else
    break
  fi
 done
 echo
 echo
 echo Now point your broswer at http://$ip:3000 to access Grafana UI, login: admin/admin
 echo Click on the 'Home' drop-down menu located at the top-left corner and select $application
 exit 0
fi
done


#
