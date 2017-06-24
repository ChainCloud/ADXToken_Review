var ADXToken = artifacts.require("./ADXToken.sol");
var Promise = require('bluebird')

contract('ADXToken', function(accounts) {

  var crowdsale;
  var token;
  var deployed = ADXToken.deployed();

  var EXPECT_FOR_ONE_ETH = 6923076;

  it("should start with 0 eth raised", function() {
    //accounts[0]
    return deployed.then(function(instance) {
      crowdsale = instance;
      return instance.getPriceRate.call();
    }).then(function(rate) {
        assert.equal(rate.valueOf(), EXPECT_FOR_ONE_ETH);
    })
  });

  it('Should allow to send ETH in exchange of Tokens', () => {
    var participiants = web3.eth.accounts.slice(4, 8).map(account => {
      return {
        account: account,
        sent: web3.toWei(1, 'ether')
      }
    })

    const currentParticipiants = participiants.slice(0, 3)

    return Promise.all(currentParticipiants.map(participiant => {
      return new Promise((resolve, reject) => {
        web3.eth.sendTransaction({
          from: participiant.account,
          to: crowdsale.address,
          value: participiant.sent,
          gas: 130000
        }, (err) => {
          if (err) reject(err) 
          
          crowdsale.balanceOf(participiant.account).then(function(res) {
            assert.equal(res.valueOf(), EXPECT_FOR_ONE_ETH);
            resolve()
          })

        })
      })
    }))
  })


  // pre-sale

  // tokens not transferrable


  // tokens transferable after end of crowdsale

  // vested tokens
});
