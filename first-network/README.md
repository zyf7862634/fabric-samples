 Etcdraft模式测试动态增删orderer节点，

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
    ./eyfn.sh up
## 清除环境
1. 清除基础网络
    ./byfn.sh down
2. 清除测试网络
    ./eyfn.sh down
