pragma solidity ^0.4.11;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/AdExContrib.sol";

contract TestContrib {
  function testInitContrib() {
    //tx.origin, tx.origin, tx.origin, now, 0
    AdExContrib contrib = AdExContrib(DeployedAddresses.AdExContrib());

    Assert.equal(contrib.getPriceRate(), 900*10000*100/30, "starts with proper price for stage one");
  }
}
