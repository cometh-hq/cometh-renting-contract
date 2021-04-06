# Premature stop

Both parties must do this process.

## Steps

1. Get the rental contract address. It's available in your interface on rental.cometh.io
2. Put this interface remix.ethereum.org

```
pragma solidity ^0.6.0;

interface IPrematureStop {
    function prematureStop() external;
}
```
3. Connect your Metamask to the Matic Network and in remix `ENVIRONMENT` choose `injected web3`
4. In the input field `At Address` put your rental contract address and then click on `At Address` button
5. Click on `prematureStop` button

Once both parties have done the previous steps, the spaceships will be transferred to their original owner.
