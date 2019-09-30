 Etcdraft模式测试动态增删orderer节点，
## 修改原始工具bug
1. 根据configtx.yaml里面得策略配置， 修改配置块orderer位置需要orderMSP.Admin角色证书得签名
但是当前cryptogen 工具生成得orderer admin 证书角色不是admin,需要修改一下:
common/tools/cryptogen/main.go: 664 行"FUNC generateOrdererOrg"
	adminUser := NodeSpec{
		isAdmin:    true,
		CommonName: fmt.Sprintf("%s@%s", adminBaseName, orgName),
	}
2. 重新编译cryptogen 工具： make cryptogen

## 准备测试环境
1. 修改configtx.yaml  注释orderer4,orderer5 相关配置
2. 修改docker-compose-etcdraft2.yaml 注释orderer4,orderer5
3. 修改byfn默认启动模式为etcdraft
	CONSENSUS_TYPE="etcdraft"
4. 新增了docker-compose-ord4.yaml 和 ordnode/ordernode.sh , ordnode/testorder.sh

## 开始测试
1. 启动基础网络
    ./byfn.sh up
2. 启动添加新orderer节点测试网络
  echo "####################TEST EtcdRAFT##############################"
  echo " eyfn.sh up 1        : add orderer4.example.com node  and test "
  echo " eyfn.sh up 2        : del orderer4.example.com node  and test "
  echo " eyfn.sh up 3        : add Ord1MSP orgnazition "
  echo " eyfn.sh up 4        : del Ord1MSP orgnazition "
  echo " eyfn.sh up 5        : add orderer.ord1.example.com node  and test "
  echo " eyfn.sh up 6        : del orderer.ord1.example.com node  and test "
  echo " eyfn.sh down        : remove orderer4.example.com and orderer.ord1.example.com "
  echo "###############################################################"

## 清除环境
1. 清除基础网络
    ./byfn.sh down
2. 清除测试网络
    ./eyfn.sh down
