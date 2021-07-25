#!/bin/bash
set -e

export MINIFIED_CONTEXT_PATH=/tmp/minified_context
export TMP_CERT_PATH=/tmp/

kubectl config view --minify > ${MINIFIED_CONTEXT_PATH}

export cluster_name=$(yq e '.contexts[].context.cluster' ${MINIFIED_CONTEXT_PATH} )
export user=$(yq e '.contexts[].context.user'  ${MINIFIED_CONTEXT_PATH} )

echo $user
echo $cluster_name
# Exit on error
abort(){
  echo $1 && exit 1
}

kube_path=$HOME/.kube
kube_config=$kube_path/config

if [ ! -f $kube_config ];
then
  abort "No $kube_config file."
fi

TMPJSON=$kube_path/kubecfg.json
# Convert yaml to json

yq e -j $kube_config > $TMPJSON

# Get CA cert
cat $TMPJSON | jq --arg x $cluster_name -r \
	'.clusters[] | select(.name==$x) | .cluster | ."certificate-authority-data" ' | base64 --decode > ${TMP_CERT_PATH}/${cluster_name}-ca.crt
if [ ! -s ${cluster_name}-ca.crt ];
then
  abort "Cannot find ${cluster_name}'s cert."
fi
# Get user client cert
cat $TMPJSON | jq --arg x $user -r \
	'.users[] | select(.name==$x) | .user | ."client-certificate-data" ' | base64 --decode > ${TMP_CERT_PATH}/$user.crt
if [ ! -s $user.crt ];
then
  abort "Cannot find $user's cert."
fi
# Get user client key
cat $TMPJSON | jq --arg x $user -r \
	'.users[] | select(.name==$x) | .user | ."client-key-data" ' | base64 --decode > ${TMP_CERT_PATH}/$user.key
if [ ! -s $user.key ];
then
  abort "Cannot find $user's key."
fi

echo "${cluster_name}-ca.crt, $user.crt, and $user's key are generated in the current directory."

# Clean up
rm -rf $TMPJSON

python3 /usr/local/bin/k8s-tcpdumper.py ${TMP_CERT_PATH}/$user.crt} ${TMP_CERT_PATH}/$user.key