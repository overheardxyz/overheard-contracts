# 流程

方案主要包含两个动作:`deposit`、`operation`。

## deposit

`deposit`是通过`DepositManager`合约进行的。用户通过指定他们的`stealth address`，并在DepositManager中托管所需的资金来实例化一个存款(deposit request)。然后一个链外筛选器(Deposit Screener)将看到存款请求并决定是否接受它。如果它接受，存款筛选器将签署请求的哈希值并为用户完成存款。如果不接受，用户可以自由取回他们的托管资金。

`deposit`过程不涉及ZKP,以下为`deposit`的完整流程:

1. 在链下生成`spending key`和`viewing key`，然后从`viewing key`中导出`canonical address`,`canonical address`可以视为一个用户的账户标识,然后任何用户(包括自己)可以将`canonical address`随机化为一个`one-time stealth address`,只有持有`viewing key`的用户能够知晓`canonical address`和`one-time stealth address`之间的联系，当然，任何用户也可以从一个`stealth addresses`中随机化一个新的`stealth addresses`，新的`stealth addresses`可以接收转账，但是只有持有`spending key`的人才能花费其中的余额。

2. 用户调用`DepositManager`合约的`instantiateDeposit`方法创建`DepositRequest`,此过程还包含向`DepositManager`转入足够数量的代币(包含存款值和代偿)。此方法参数包含存款值`values`和一个指定的`stealth addresses`。

3. 调用`completeDeposit`来完成存款，方法参数包含`DepositRequest`和` signature`,其中`signature`是`Deposit Screener`对`DepositRequest`的签名，签名和`DepositRequest`存在性校验完成后，会调用`Teller`合约的`depositFunds`方法将资产转移至Teller合约,gas补偿给`Screener`。

4. `Handler`合约维护着所有 "有效 "票据(notes)的承诺的Merkle树，为了花费一个note，用户必须证明它的`note commitment`包含在承诺树中。`Teller`合约的`depositFunds`方法除了转移资产，还会调用`Handler`合约的`handleDeposit`方法来插入此资产对应的一个`NoteCommitment`至`Merkle commitment tree`，后续树的状态可以被访问，以验证`joinsplits`是否有效，以及`notes`是否已经被花费等。

## operation
一旦资金被存入，所有资金的使用都是由一个单一的`Teller`合约发起的，该合约接受一捆操作(`a bundle of operations`,`operations`由`bundler`服务收集)，验证其证明，然后将单个操作的处理和执行委托给`Handler`合约。

详细过程如下:
1. 用户向`bundler`发送`Operation`(用户使用资产的唯一方法是发送`Operation`),`bundler`收集多个`operation`并包装成一个`bundle`，然后调用`Teller`合约的`processBundle`方法处理这一批`operations`。

2. 对于每一个`operation`,会验证其`joinsplit proof`,只有通过验证，才能进行接下来的处理过程。

3. 验证通过后，会调用`Handler`合约的`handleOperation`方法处理每一个`operation`

4. 根据operation的内容来更新承诺树，此处做了特殊处理，引入了一个链下角色`subtree updater`,在链上的承诺树中添加了一个特殊字段`accumulatorQueue`，即`handleOperation`并不会立即更新承诺树的状态,而是将`insertions`放入队列，`subtree updater`持续观测此队列，当队列满时，将其取出，并应用于本地的树的副本中，计算new root和`subtreeUpdata proof`,调用`subtreeUpdate`合约方法来更新链上的树的状态,`subtreeUpdate`会验证proof，若验证通过，则会清空队列，并将`root`设置为`new root`。

在整个过程中，需要计算bundle、Handler的gas补偿，例如，在handler operation结束时，向bundle支付gas补偿等。





