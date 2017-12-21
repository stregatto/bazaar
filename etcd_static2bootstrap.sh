#!/bin/bash
set -e

# this script require:
# etcdctl
# curl

function displayHelp {
  filename=$(basename "$0")
  echo "${filename} Help"
  echo "Switch:"
  echo " -c|--cluster-name The name of the cluster "
  echo " -b|--bootstrap-server The ip address or the name|fqdn of the bootstrap etcd cluster|server"
  echo " -s|--cluster-size The number of component of cluster accordingly the etcd documentation"
  echo " -C|--existing-Cluster-Name The ip address or the name|fqdn of the existing etcd cluster|server"
  echo " -C|--existing-Cluster-Port The tcp port of the existing etcd cluster|server (optional, default 2379)"
  echo " -p|--bootstrap-port The tcp port of the bootsrap cluster|server (optional, default 2379)"
  echo " -h|--help display this help"
  echo "Usage:"
  echo " ${filename} -c CLUSTERNAME -s CLUSTERSIZE -b BOOTSTRAPSERVERNAME -C EXISTINGCLUSTERNAME [-p BOOTSTRAPSERVERPORT -P EXISTINGCLUSTERPORT (optional)]"
  exit
}

function displayErrorHelp {
  echo "Wrong number of parameters"
  echo "cluster-name, bootstrap-server, cluster-size are mandatory"
  displayHelp
}

function createCluster {
  echo -e "\n--- Creating the CLUSTER ${CLUSTER_NAME} key --- \n"
  curl -X PUT http://${BOOTSTRAP_NAME}:${BOOTSTRAP_PORT}/v2/keys/discovery/${CLUSTER_NAME}/_config/size -d value=${CLUSTER_SIZE}
  if [[ $? -eq 0 ]]
    then
      echo -e "\nDONE"
    else
      echo -e "\nERROR"
  fi
}

function migrateMembers {
  while read line
    do 
      for i in $line
      do
        case $i in
          [0-9a-zA-Z]*\:)
            id=${i%:*}
          ;;
          name*)
            name=${i##*=}
          ;;
         peerURLs*)
           peerURLs=${i##*=}
         ;;
         clientURLs*) clientURLs=${i##*=}
           clientURLs=${i##*=}
         ;;
         esac
      done
      echo -e "--- Creating entries in ${CLUSTER_NAME} kyes from actual configuration\n " 
      etcdctl --endpoints http://${BOOTSTRAP_NAME}:${EXISTING_PORT} set discovery/${CLUSTER_NAME}/${id} ${name}=${peerURLs}
    done < <(etcdctl --endpoints http://${EXISTING_NAME}:${EXISTING_PORT} member list)
}


POSITIONAL=()
PARAMS=$#
CLUSTER_NAME=''
CLUSTER_SIZE=''
EXISTING_NAME=''
EXISTING_PORT=2379
BOOTSTRAP_NAME=''
BOOTSTRAP_PORT=2379

while [[ $# -gt 0 ]]
do
  key="$1"
  case $key in
    -c|--cluster-name)
    CLUSTER_NAME="$2"
    shift
    shift
    ;;
    -b|--bootstrap-server)
      BOOTSTRAP_NAME="$2"
      shift
      shift
    ;;
    -s|--cluster-size)
      CLUSTER_SIZE="$2"
      shift
      shift
    ;;
    -p|--bootstrap-port)
      BOOTSTRAP_PORT="$2"
      shift
      shift
    ;;
    -C|----existing-Cluster-Name)
      EXISTING_NAME="$2"
      shift
      shift
    ;;
    -P|--existing-Cluster-Port)
      EXISTING_PORT="$2"
      shift
      shift
    ;;
    -h|--help)
      displayHelp
      exit
	;;
    *)    # unknown option
      echo "unknown parameter"
      echo "use -h or --help to display the help online"
    ;;
  esac
done

if [[ ${PARAMS} -eq 0 ]]
  then 
    displayHelp
fi

if [[ "${CLUSTER_NAME}" == "" ]] || [[ "${CLUSTER_SIZE}" == "" ]] || [[ "${BOOTSTRAP_NAME}" == "" ]] || [[ ${EXISTING_NAME} == "" ]]
  then
    displayErrorHelp
fi


createCluster
migrateMembers
