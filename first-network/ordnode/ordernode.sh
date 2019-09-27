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

#向指定channel添加orderer节点
function addOrdererNode(){
    CHANNEL=$1
    echo "Add orderer node to channel ：$CHANNEL"
    echo "创建不同channel的缓存目录"
    CURPATH='/opt/gopath/src/github.com/hyperledger/fabric/peer/ordnode/'${CHANNEL}''
    rm -rf $CURPATH
    mkdir -p $CURPATH
    echo "进入配置文件缓存目录"
    cd  $CURPATH
    echo "用orderer.Admin身份拉取指定channel最新配置块，并提前出有效的数据放入config.json文件"
    setOrdererGlobals
    peer channel fetch config config_block.pb -o orderer.example.com:7050 -c $CHANNEL --tls --cafile $ORDERER_CA
    echo "解析配置块文件取出有用的配置,并转换写入config.json文件"
    configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json
    echo "将config.json文件中Orderer节点证书字段 和 ordererAddress字段添加上新orderer节点信息 "
    #base64 xx -w 0  禁用换行
    CERT=$(base64 /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer4.example.com/tls/server.crt -w 0)
    #json格式中间不要有空格
    STRUCT='{"client_tls_cert":"'$CERT'","host":"orderer4.example.com","port":7050,"server_tls_cert":"'$CERT'"}'
    echo "将要增加新节点的证书内容结构添加到json文件的指定字段中"
    echo "将节点地址添加到json文件的指定字段中并写入新文件"
#    set -x
    jq '.channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters += ['${STRUCT}']' config.json > temp.json
    jq '.channel_group.values.OrdererAddresses.value.addresses += ["orderer4.example.com:7050"]' temp.json > config_modify.json
#    set +x
    echo "根据修改前后的2个json文件,生成指定channel变化的pb文件"
    createConfigUpdate ${CHANNEL} config.json config_modify.json update_in_envelope.pb
    echo "更新channel，用orderer 签名"
    setOrdererGlobals
    peer channel signconfigtx -f update_in_envelope.pb
    echo "发送更新配置块交易"
    set -x
    peer channel update -f update_in_envelope.pb -c ${CHANNEL} -o orderer.example.com:7050 --tls --cafile ${ORDERER_CA}
    set +x
    cd -
}

#验证jq工具是否存在，不存在就安装
checkInstallJq
# 添加到系统通道
addOrdererNode byfn-sys-channel
# 添加到应用通道
addOrdererNode mychannel

echo "等待orderer节点raft更新完成"
cd ordnode
echo "拉取最新的的系统配置块写入byfn-sys-channel_last.block文件"
setOrdererGlobals
set -x
peer channel fetch config byfn-sys-channel_last.block -o orderer.example.com:7050 -c byfn-sys-channel --tls --cafile $ORDERER_CA
set +x
exit 0
