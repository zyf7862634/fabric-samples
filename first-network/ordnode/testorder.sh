#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# This script is designed to be run in the org3cli container as the
# final step of the EYFN tutorial. It simply issues a couple of
# chaincode requests through the org3 peers to check that org3 was
# properly added to the network previously setup in the BYFN tutorial.
#

echo
echo " ____    _____      _      ____    _____ "
echo "/ ___|  |_   _|    / \    |  _ \  |_   _|"
echo "\___ \    | |     / _ \   | |_) |   | |  "
echo " ___) |   | |    / ___ \  |  _ <    | |  "
echo "|____/    |_|   /_/   \_\ |_| \_\   |_|  "
echo
echo "Extend your first network (EYFN) test"
echo
CHANNEL_NAME="$1"
DELAY="$2"
LANGUAGE="$3"
TIMEOUT="$4"
ORDERHOST="$5"
: ${CHANNEL_NAME:="mychannel"}
: ${TIMEOUT:="10"}
: ${LANGUAGE:="golang"}
: ${ORDERHOST:="orderer4.example.com"}
LANGUAGE=`echo "$LANGUAGE" | tr [:upper:] [:lower:]`
COUNTER=1
MAX_RETRY=5

CC_SRC_PATH="github.com/chaincode/chaincode_example02/go/"
if [ "$LANGUAGE" = "node" ]; then
	CC_SRC_PATH="/opt/gopath/src/github.com/chaincode/chaincode_example02/node/"
fi

echo "Channel name : "$CHANNEL_NAME

# import functions
. scripts/utils.sh

#check orderer is available
checkOrderAvailability() {
	#Use orderer's MSP for fetching system channel config block
    setOrdererGlobals
	local rc=1
	local starttime=$(date +%s)
    if [ "$ORDERHOST" == "orderer.ord1.example.com" ]; then
        ORDERER_TLS_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/ord1.example.com/orderers/orderer.ord1.example.com/msp/tlscacerts/tlsca.ord1.example.com-cert.pem
    else
        ORDERER_TLS_CA=$ORDERER_CA
    fi
	# continue to poll
	# we either get a successful response, or reach TIMEOUT
	while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
	do
		 sleep 3
		 set -x
		 echo "Attempting to fetch channel $CHANNEL_NAME'' ...$(($(date +%s)-starttime)) secs"
		 if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
			 peer channel fetch 0 0_block.pb -o $ORDERHOST:7050 -c "$CHANNEL_NAME" >&log.txt
		 else
			 peer channel fetch 0 0_block.pb -o $ORDERHOST:7050 -c "$CHANNEL_NAME" --tls --cafile $ORDERER_TLS_CA >&log.txt
		 fi
		 set +x
		 test $? -eq 0 && VALUE=$(cat log.txt | awk '/Received block/ {print $NF}')
		 test "$VALUE" = "0" && let rc=0
	done
	cat log.txt
	verifyResult $rc "the  Orderer  is not available for $CHANNEL_NAME, Please try again ..."
	echo "=====================the   Orderernode: $ORDERHOST  is  available for $CHANNEL_NAME===================== "
	echo
}

chaincodeInvokeByOrderer() {
  parsePeerConnectionParameters $@
  res=$?
  verifyResult $res "Invoke transaction failed on channel '$CHANNEL_NAME' due to uneven number of peer and org parameters "
  if [ "$ORDERHOST" == "orderer.ord1.example.com" ]; then
    ORDERER_TLS_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/ord1.example.com/orderers/orderer.ord1.example.com/msp/tlscacerts/tlsca.ord1.example.com-cert.pem
  else
    ORDERER_TLS_CA=$ORDERER_CA
  fi
  # while 'peer chaincode' command can get the orderer endpoint from the
  # peer (if join was successful), let's supply it directly as we know
  # it using the "-o" option
  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
    set -x
    peer chaincode invoke -o $ORDERHOST:7050 -C $CHANNEL_NAME -n mycc $PEER_CONN_PARMS -c '{"Args":["invoke","a","b","10"]}' >&log.txt
    res=$?
    set +x
  else
    set -x
    peer chaincode invoke -o $ORDERHOST:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_TLS_CA -C $CHANNEL_NAME -n mycc $PEER_CONN_PARMS -c '{"Args":["invoke","a","b","10"]}' >&log.txt
    res=$?
    set +x
  fi
  cat log.txt
  verifyResult $res "Invoke execution on $PEERS failed "
  echo "===================== Invoke transaction successful on $PEERS on channel '$CHANNEL_NAME' ===================== "
  echo
}

function queryValue() {
  setGlobals 0 1
  local rc=1
  local starttime=$(date +%s)

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while
    test "$(($(date +%s) - starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
    sleep 3
    set -x
    peer chaincode query -C mychannel -n mycc -c '{"Args":["query","a"]}' > log.txt
    res=$?
    set +x
    test $res -eq 0 &&  VALUE=$(cat log.txt | egrep '^[0-9]+$') && let rc=0
    echo "--------Query Result is $VALUE---------------"
  done
}
echo "检测orderer节点是否已经可以用于指定channel"
checkOrderAvailability
echo "先验证原有orderer做交易是否正常"
echo "Sending invoke transaction on peer0.org1 peer0.org2..."
chaincodeInvoke 0 1 0 2
echo "Querying chaincode on peer0.org1..."
queryValue
#chaincodeQuery 0 1 80

echo "再验证新部署orderer做交易是否正常"
# Invoke chaincode on peer0.org1 and peer0.org2
echo "Sending invoke transaction on peer0.org1 peer0.org2..."
chaincodeInvokeByOrderer 0 1 0 2
echo "Querying chaincode on peer0.org1..."
chaincodeQuery 0 1 `expr $VALUE - 10`

echo
echo "========= All GOOD, New orderer4 test execution completed =========== "
echo

echo
echo " _____   _   _   ____   "
echo "| ____| | \ | | |  _ \  "
echo "|  _|   |  \| | | | | | "
echo "| |___  | |\  | | |_| | "
echo "|_____| |_| \_| |____/  "
echo

exit 0
