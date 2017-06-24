var ADXToken = artifacts.require("./ADXToken.sol");

module.exports = function(deployer) {
  deployer.deploy(ADXToken, 
  	web3.eth.accounts[0], // multisig
  	web3.eth.accounts[0], // team
  	Math.floor(Date.now()/1000)-10, // public sale start
	Math.floor(Date.now()/1000)-7*24*60*60, // private sale start
  	30800*1000000000000000000, // ETH hard cap, in wei
  	web3.eth.accounts[6], 5047335,
  	web3.eth.accounts[7], 5047335, // TODO: change accordingly
  	web3.eth.accounts[8], 2340000 
  );
};
