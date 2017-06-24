pragma solidity ^0.4.11;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/ADXToken.sol";

contract TestContrib {
  //public uint initialBalance = 1 wei;
  
  ADXToken contrib = ADXToken(DeployedAddresses.ADXToken());


  function testInitContrib() {
    //tx.origin, tx.origin, tx.origin, now, 0
    Assert.equal(contrib.getPriceRate(), 11700000, "starts with proper price for stage one");
  }

}
