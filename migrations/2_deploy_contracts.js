var AdExContrib = artifacts.require("./AdExContrib.sol");

module.exports = function(deployer) {
  deployer.deploy(AdExContrib, web3.eth.accounts[0], web3.eth.accounts[0],  web3.eth.accounts[0], Math.floor(Date.now()/1000), 0);
};
