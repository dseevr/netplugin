#!/bin/bash

# GetKubernetes fetches k8s binaries from the k8 release repo
function GetKubernetes {

  # fetch kubernetes released binaries
  pushd .
  mkdir -p $top_dir/k8s-$k8sVer
  if [ -f $top_dir/k8s-$k8sVer/kubernetes.tar.gz ]; then
    echo "k8s-$k8sVer/kubernetes.tar.gz found, not fetching."
    rm -rf $top_dir/k8s-$k8sVer/kubernetes
    rm -rf $top_dir/k8s-$k8sVer/bin
  else
    cd $top_dir/k8s-$k8sVer
    wget https://github.com/kubernetes/kubernetes/releases/download/$k8sVer/kubernetes.tar.gz
  fi

  # untar kubernetes released binaries
  cd $top_dir/k8s-$k8sVer
  tar xvfz kubernetes.tar.gz kubernetes/server/kubernetes-server-linux-amd64.tar.gz
  tar xvfz kubernetes/server/kubernetes-server-linux-amd64.tar.gz
  popd

  if [ ! -f $top_dir/k8s-$k8sVer/kubernetes/server/bin/kubelet ]; then
    echo "Error kubelet not found after fetch/extraction"
    exit 1
  fi
}

# GetContiv fetches k8s binaries from the contiv release repo
function GetContiv {

  # fetch contiv binaries
  pushd .
  mkdir -p $top_dir/contiv_bin
  if [ -f $top_dir/contiv_bin/netplugin-$contivVer.tar.bz2 ]; then
    echo "netplugin-$contivVer.tar.bz2 found, not fetching."
  else
    cd $top_dir/contiv_bin
    wget https://github.com/contiv/netplugin/releases/download/$contivVer/netplugin-$contivVer.tar.bz2
    tar xvfj netplugin-$contivVer.tar.bz2
  fi
  popd

  if [ ! -f $top_dir/contiv_bin/contivk8s ]; then
    echo "Error contivk8s not found after fetch/extraction"
    exit 1
  fi
}

#GetContrib fetches contrib if not present

function GetContrib {
	pushd .
	if [ -f $top_dir/contrib ]; then
    		echo "netplugin-$contivVer.tar.bz2 found, not fetching."
  	else
		git clone https://github.com/jojimt/contrib -b contiv 
  	fi
	popd
}

# kubernetes version to use -- defaults to v1.2.3
: ${k8sVer:=v1.2.3}

# contiv version
: ${contivVer:=v0.1-09-08-2016.20-56-40.UTC}

top_dir=$(git rev-parse --show-toplevel | sed 's|/[^/]*$||')

GetKubernetes
GetContrib

k8_sanity=${CONTIV_K8}
if [ "$k8_sanity" == "" ]; then
   GetContiv
fi

if [ "$k8_sanity" == "1" ]; then
   if [ ! -f ./contrib ]; then
      git clone https://github.com/jojimt/contrib -b contiv
   fi
fi
# exit on any error
set -e


# bring up vms
vagrant up

# generate inventory
./vagrant_cluster.py


if [ "$k8_sanity" == "" ]; then
# run ansible
ansible-playbook -i .contiv_k8s_inventory ./contrib/ansible/cluster.yml --skip-tags "contiv_restart" -e "networking=contiv contiv_fabric_mode=default localBuildOutput=$top_dir/k8s-$k8sVer/kubernetes/server/bin contiv_bin_path=$top_dir/contiv_bin contiv_demo=True"
fi
