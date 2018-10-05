wget http://package.mapr.com/tools/KubernetesDataFabric/v1.0.1/kdf-plugin-centos.yaml -O /tmp/kdf-plugin-centos.yaml
endpoint=`grep server ~/.kube/config | awk -F\/\/ '{print $2}' | sed 's/"//g'`
sed -i s#changeme\!:6443#$endpoint:443#g /tmp/kdf-plugin-centos.yaml

