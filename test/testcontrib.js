var AdExContrib = artifacts.require("./AdExContrib.sol");

contract('AdExContrib', function(accounts) {
  it("should start with 0 eth raised", function() {
    //accounts[0]
    return AdExContrib.deployed().then(function(instance) {
      return instance.getPriceRate.call();
    }).then(function(rate) {
        assert.equal(rate.valueOf(), 900*10000*100/30);
    });
  });

});
