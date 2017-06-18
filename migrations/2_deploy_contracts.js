var AdExContract = artifacts.require("./AdExContract.sol");

module.exports = function(deployer) {
  deployer.deploy(AdExContract);
};
