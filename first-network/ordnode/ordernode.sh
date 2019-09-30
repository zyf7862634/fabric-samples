#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# This script is designed to be run in the org3cli container as the
# first step of the EYFN tutorial.  It creates and submits a
# configuration transaction to add org3 to the network previously
# setup in the BYFN tutorial.
#

CUR_CHANNEL=""
: ${CUR_CHANNEL:="mychannel"}
ORDER_HOST=""
# import utils
. scripts/utils.sh

function checkInstallJq() {
  which jq
  if [ "$?" -ne 0 ]; then
    echo "jq tool not found. Start Installing jq"
    apt-get -y update && apt-get -y install jq
  fi
  echo "###########  Jq tool Installed. ###########"
}

function createDirFetchConfig() {
    echo "创建不同channel的缓存目录"
    CURPATH='/opt/gopath/src/github.com/hyperledger/fabric/peer/ordnode/'${CUR_CHANNEL}''
    rm -rf $CURPATH
    mkdir -p $CURPATH
    echo "进入配置文件缓存目录"
    cd  $CURPATH
    echo "用orderer.Admin身份拉取指定channel最新配置块，并提前出有效的数据放入config.json文件"
    setOrdererGlobals
    peer channel fetch config config_block.pb -o orderer.example.com:7050 -c $CUR_CHANNEL --tls --cafile $ORDERER_CA
    echo "解析配置块文件取出有用的配置,并转换写入config.json文件"
    configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json
}

function createConfigDeltaAndSendTx() {
    echo "根据修改前后的2个json文件,生成指定channel变化的pb文件"
    createConfigUpdate ${CUR_CHANNEL} config.json modified_config.json update_in_envelope.pb
    echo "更新channel，用orderer 签名"
    setOrdererGlobals
    peer channel signconfigtx -f update_in_envelope.pb
    if [ "$ORDER_HOST" == "orderer.ord1.example.com" ]; then
        CORE_PEER_LOCALMSPID="Ord1MSP"
        CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/ord1.example.com/orderers/orderer.ord1.example.com/msp/tlscacerts/tlsca.ord1.example.com-cert.pem
        CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/ord1.example.com/users/Admin@ord1.example.com/msp
        peer channel signconfigtx -f update_in_envelope.pb
    fi
    echo "发送更新配置块交易"
    set -x
    peer channel update -f update_in_envelope.pb -c ${CUR_CHANNEL} -o orderer.example.com:7050 --tls --cafile ${ORDERER_CA}
    set +x
}

#向指定channel添加orderer组织
function ChangeOrdOrg() {
    CUR_CHANNEL=$1
    createDirFetchConfig
    # Modify the configuration to append the new org
    set -x
    if [ "$2" == "add" ]; then
        jq -s '.[0] * {"channel_group":{"groups":{"Orderer":{"groups": {"Ord1MSP":.[1]}}}}}' config.json ../../channel-artifacts/ord1.json > modified_config.json
        ORDER_HOST="orderer4.example.com"
    else
        jq  'del(.channel_group.groups.Orderer.groups.Ord1MSP)' config.json > modified_config.json
        ORDER_HOST="orderer.ord1.example.com"
    fi
    set +x
    createConfigDeltaAndSendTx

}

#向指定channel添加orderer节点
function ChangeOrdererNode(){
    CUR_CHANNEL=$1
    ORDER_HOST=$2
    if [ "$3" == "add" ]; then
        OPERATION="+="
    elif [ "$3" == "del" ]; then
        OPERATION="-="
    fi
    createDirFetchConfig
    echo "将config.json文件中Orderer节点证书字段 和 ordererAddress字段添加上新orderer节点信息 "
    #base64 xx -w 0  禁用换行
    if [ "$ORDER_HOST" == "orderer4.example.com" ]; then
        CERT=$(base64 /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer4.example.com/tls/server.crt -w 0)
    else
        CERT=$(base64 /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/ord1.example.com/orderers/orderer.ord1.example.com/tls/server.crt -w 0)
    fi
    #json格式中间不要有空格
    STRUCT='{"client_tls_cert":"'$CERT'","host":"'$ORDER_HOST'","port":7050,"server_tls_cert":"'$CERT'"}'
    echo "将要增加/删除新节点的证书内容结构添加/删除到对应json文件的指定字段中"
    echo "将节点地址添加/删除到json文件的指定字段中并写入新文件"
    echo "############# $3 orderer for $CUR_CHANNEL ############"
#    set -x
    jq '.channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters '${OPERATION}' ['${STRUCT}']' config.json > temp.json
    jq '.channel_group.values.OrdererAddresses.value.addresses '${OPERATION}' ["'$ORDER_HOST':7050"]' temp.json > modified_config.json
#    set +x
    createConfigDeltaAndSendTx
    cd -
}

function fetchLatestConfig(){
    echo "等待orderer节点raft更新完成"
    cd /opt/gopath/src/github.com/hyperledger/fabric/peer/ordnode/byfn-sys-channel
    echo "拉取最新的的系统配置块写入byfn-sys-channel_last.block文件"
    setOrdererGlobals
    set -x
    peer channel fetch config byfn-sys-channel_last.block -o orderer.example.com:7050 -c byfn-sys-channel --tls --cafile $ORDERER_CA
    set +x
}

#验证jq工具是否存在，不存在就安装
checkInstallJq

if [ "$1" == "ordernode" ]; then
    # 更新到系统通道，应用通道 "$2 : "add" or "del"
    ChangeOrdererNode byfn-sys-channel orderer4.example.com $2
    ChangeOrdererNode mychannel orderer4.example.com $2
    fetchLatestConfig
elif [ "$1" == "ord1org" ]; then
    # 更新到系统通道，应用通道 "$2 : "add" or "del"
    ChangeOrdOrg byfn-sys-channel $2
    ChangeOrdOrg mychannel $2
    fetchLatestConfig
elif [ "$1" == "ord1node" ]; then
     # 更新到系统通道，应用通道 "$2 : "add" or "del"
    ChangeOrdererNode byfn-sys-channel orderer.ord1.example.com $2
    ChangeOrdererNode mychannel orderer.ord1.example.com $2
    fetchLatestConfig
else
    echo "shell script args error"
fi