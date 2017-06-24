var ADXToken = artifacts.require("./ADXToken.sol");

module.exports = function(deployer) {
  deployer.deploy(ADXToken, web3.eth.accounts[0], web3.eth.accounts[0], Math.floor(Date.now()/1000)-30, 0, 30800, web3.eth.accounts[6], web3.eth.accounts[7], web3.eth.accounts[8]);
};
