pragma solidity ^0.4.11;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/AdExContrib.sol";

contract TestContrib {

  function testInitContrib() {
    //tx.origin, tx.origin, tx.origin, now, 0
    AdExContrib contrib = AdExContrib(DeployedAddresses.AdExContrib());

    Assert.equal(contrib.etherRaised, 0, "starts with 0 ether raised");
  }

}
