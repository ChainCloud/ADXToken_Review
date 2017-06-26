pragma solidity ^0.4.11;

// QUESTIONS FOR AUDITORS:
// - Considering we inherit from VestedToken, how much does that hit at our gas price?
// - Ensure max supply is 100,000,000
// - Ensure that even if not totalSupply is sold, tokens would still be transferrable after (we will up to totalSupply by creating adEx tokens)

// vesting: 365 days, 365 days / 4 vesting

import "../zeppelin-solidity/contracts/SafeMath.sol";
import "../zeppelin-solidity/contracts/token/VestedToken.sol";

contract ADXToken is VestedToken {
  //FIELDS
  string public name = "AdEx";
  string public symbol = "ADX";
  uint public decimals = 4;

  //CONSTANTS
  //Time limits
  uint public constant STAGE_ONE_TIME_END = 24 hours; // first day bonus
  uint public constant STAGE_TWO_TIME_END = 1 weeks; // first week bonus
  uint public constant STAGE_THREE_TIME_END = 4 weeks;
  
  // Multiplier for the decimals
  uint private constant DECIMALS = 10000;

  //Prices of ADX
  uint public constant PRICE_STANDARD    = 900*DECIMALS; // ADX received per one ETH; MAX_SUPPLY / (valuation / ethPrice)

  ///// [review] 1170 tokens/1 ETH 1 day
  uint public constant PRICE_STAGE_ONE   = PRICE_STANDARD * 130/100; // 1ETH = 30% more ADX
  ///// [review] 1035 tokens/1 ETH days 2,3,4,5,6,7
  uint public constant PRICE_STAGE_TWO   = PRICE_STANDARD * 115/100; // 1ETH = 15% more ADX
  ///// [review] 900 tokens/1 ETH later
  uint public constant PRICE_STAGE_THREE = PRICE_STANDARD;

  //ADX Token Limits
  ///// [review] total is 100000000 
  uint public constant ALLOC_TEAM =         16000000*DECIMALS; // team + advisors
  uint public constant ALLOC_BOUNTIES =      2000000*DECIMALS;
  uint public constant ALLOC_WINGS =         2000000*DECIMALS;
  uint public constant ALLOC_CROWDSALE =    80000000*DECIMALS;
  uint public constant PREBUY_PORTION_MAX = 20000000*DECIMALS; // this is redundantly more than what will be pre-sold
  
  //ASSIGNED IN INITIALIZATION
  //Start and end times
  uint public publicStartTime; // Time in seconds public crowd fund starts.
  uint public privateStartTime; // Time in seconds when pre-buy can purchase up to 31250 ETH worth of ADX;

  //// [review] publicStartTime + 4 weeks
  uint public publicEndTime; // Time in seconds crowdsale ends
  uint public hardcapInEth;

  //Special Addresses
  address public multisigAddress; // Address to which all ether flows.
  address public adexTeamAddress; // Address to which ALLOC_TEAM, ALLOC_BOUNTIES, ALLOC_WINGS is (ultimately) sent to.

  address public adexFundAddress;
  address public ownerAddress; // Address of the contract owner. Can halt the crowdsale.
  address public preBuy1; // Address used by pre-buy
  address public preBuy2; // Address used by pre-buy
  address public preBuy3; // Address used by pre-buy
  uint public preBuyPrice1; // price for pre-buy
  uint public preBuyPrice2; // price for pre-buy
  uint public preBuyPrice3; // price for pre-buy

  //Running totals
  uint public etherRaised; // Total Ether raised.
  uint public ADXSold; // Total ADX created
  uint public prebuyPortionTotal; // Total of Tokens purchased by pre-buy. Not to exceed PREBUY_PORTION_MAX.
  
  //booleans
  bool public halted; // halts the crowd sale if true.

  // MODIFIERS
  //Is currently in the period after the private start time and before the public start time.
  ///// [review] OK
  modifier is_pre_crowdfund_period() {
    if ((now >= publicStartTime) || (now < privateStartTime)) throw;
    _;
  }

  //Is currently the crowdfund period
  ///// [review] OK
  modifier is_crowdfund_period() {
    if ((now < publicStartTime) || (now >= publicEndTime)) throw;
    _;
  }

  // Is completed
  ///// [review] OK
  modifier is_crowdfund_completed() {
    if (!isCrowdfundCompleted()) throw;
    _;
  }
  ///// [review] OK
  function isCrowdfundCompleted() internal returns (bool) {
    if ((now > publicEndTime) || (ADXSold >= ALLOC_CROWDSALE)) return true;
    return false;
  }

  //May only be called by the owner address
  ///// [review] OK
  modifier only_owner() {
    if (msg.sender != ownerAddress) throw;
    _;
  }

  //May only be called if the crowdfund has not been halted
  ///// [review] OK
  modifier is_not_halted() {
    if (halted) throw;
    _;
  }

  // EVENTS
  event PreBuy(uint _amount);
  event Buy(address indexed _recipient, uint _amount);

  // Initialization contract assigns address of crowdfund contract and end time.
  function ADXToken(
    address _multisig,
    address _adexTeam,
    address _adexFund,
    uint _publicStartTime,
    uint _privateStartTime,
    uint _hardcapInEth,
    address _prebuy1, uint _preBuyPrice1,
    address _prebuy2, uint _preBuyPrice2,
    address _prebuy3, uint _preBuyPrice3
  ) {
    ownerAddress = msg.sender;
    ///// [review] add check that publicStartTime>privateStartTime
    publicStartTime = _publicStartTime;
    privateStartTime = _privateStartTime;
    publicEndTime = _publicStartTime + 4 weeks;
    multisigAddress = _multisig;
    adexTeamAddress = _adexTeam;
    adexFundAddress = _adexFund;

    hardcapInEth = _hardcapInEth;

    preBuy1 = _prebuy1;
    preBuyPrice1 = _preBuyPrice1;
    preBuy2 = _prebuy2;
    preBuyPrice3 = _preBuyPrice2;
    preBuy3 = _prebuy3;
    preBuyPrice3 = _preBuyPrice3;

    ///// [review] optional - better move each to separate account
    balances[adexTeamAddress] += ALLOC_BOUNTIES;
    balances[adexTeamAddress] += ALLOC_WINGS;

    ///// [review] this will be moved to adexTeamAddress (vested) in the 'grantVested' method
    balances[ownerAddress] += ALLOC_TEAM;

    balances[ownerAddress] += ALLOC_CROWDSALE;
  }

  // Transfer amount of tokens from sender account to recipient.
  // Only callable after the crowd fund is completed
  ///// [review] use 'is_crowdfund_completed' modifier here
  function transfer(address _to, uint _value)
  {
    if (_to == msg.sender) return; // no-op, allow even during crowdsale, in order to work around using grantVestedTokens() while in crowdsale
    if (!isCrowdfundCompleted()) throw;
    super.transfer(_to, _value);
  }

  // Transfer amount of tokens from a specified address to a recipient.
  // Transfer amount of tokens from sender account to recipient.
  ///// [review] OK
  function transferFrom(address _from, address _to, uint _value)
    is_crowdfund_completed
  {
    super.transferFrom(_from, _to, _value);
  }

  //constant function returns the current ADX price.
  ///// [review] use 'is_crowdfund_period' modifier here
  function getPriceRate()
      constant
      returns (uint o_rate)
  {
      uint delta = SafeMath.sub(now, publicStartTime);

      if (delta > STAGE_TWO_TIME_END) return PRICE_STAGE_THREE;
      if (delta > STAGE_ONE_TIME_END) return PRICE_STAGE_TWO;

      return (PRICE_STAGE_ONE);
  }

  // calculates wmount of ADX we get, given the wei and the rates we've defined per 1 eth
  ///// [review] OK
  function calcAmount(uint _wei, uint _rate) 
    constant
    returns (uint) 
  {
    return SafeMath.div(SafeMath.mul(_wei, _rate), 1 ether);
  } 
  
  // Given the rate of a purchase and the remaining tokens in this tranche, it
  // will throw if the sale would take it past the limit of the tranche.
  // Returns `amount` in scope as the number of ADX tokens that it will purchase.
  ///// [review] OK, but too complex for 1 function
  function processPurchase(uint _rate, uint _remaining)
    internal
    returns (uint o_amount)
  {
    ///// [review] better move to modifier
    if (etherRaised > hardcapInEth) throw;

    o_amount = calcAmount(msg.value, _rate);

    if (o_amount > _remaining) throw;
    if (!multisigAddress.send(msg.value)) throw;

    balances[ownerAddress] = balances[ownerAddress].sub(o_amount);
    balances[msg.sender] = balances[msg.sender].add(o_amount);

    ///// [review] better use SafeMath.add
    ADXSold += o_amount;
    ///// [review] better use SafeMath.add
    etherRaised += msg.value;
  }

  //Special Function can only be called by pre-buy and only during the pre-crowdsale period.
  ///// [review] OK
  function preBuy()
    payable
    is_pre_crowdfund_period
    is_not_halted
  {
    // Pre-buy participants would get the first-day price, as well as a bonus of vested tokens
    uint priceVested = 0;

    if (msg.sender == preBuy1) priceVested = preBuyPrice1;
    if (msg.sender == preBuy2) priceVested = preBuyPrice2;
    if (msg.sender == preBuy3) priceVested = preBuyPrice3;

    if (priceVested == 0) throw;

    ///// [review] the price on a prebuy is lower than price for public (later)
    ///// [review] msg.sender receives tokens
    uint amount = processPurchase(PRICE_STAGE_ONE + priceVested, SafeMath.sub(PREBUY_PORTION_MAX, prebuyPortionTotal));

    ///// [review] vested tokens are issued for msg.sender
    grantVestedTokens(msg.sender, calcAmount(msg.value, priceVested), 
      uint64(now), uint64(now) + 91 days, uint64(now) + 365 days, 
      false, false
    );
    ///// [review] better use SafeMath.add
    prebuyPortionTotal += amount;
    PreBuy(amount);
  }

  //Default function called by sending Ether to this address with no arguments.
  //Results in creation of new ADX Tokens if transaction would not exceed hard limit of ADX Token.
  ///// [review] OK
  function()
    payable
    is_crowdfund_period
    is_not_halted
  {
    uint amount = processPurchase(getPriceRate(), SafeMath.sub(ALLOC_CROWDSALE, ADXSold));
    Buy(msg.sender, amount);
  }

  // To be called at the end of crowdfund period
  ///// [review] OK
  function grantVested()
    is_crowdfund_completed
    only_owner
    is_not_halted
  {
    // Grant tokens pre-allocated for the team
    grantVestedTokens(
      adexTeamAddress, ALLOC_TEAM,
      uint64(now), uint64(now) + 91 days , uint64(now) + 365 days, 
      false, false
    );

    // Grant tokens that remain after crowdsale to the AdEx fund, vested for 2 years
    grantVestedTokens(
      adexFundAddress, balances[ownerAddress],
      uint64(now), uint64(now) + 182 days , uint64(now) + 730 days, 
      false, false
    );
  }

  //May be used by owner of contract to halt crowdsale and no longer except ether.
  ///// [review] OK
  function toggleHalt(bool _halted)
    only_owner
  {
    halted = _halted;
  }

  //failsafe drain
  ///// [review] OK
  function drain()
    only_owner
  {
    if (!ownerAddress.send(this.balance)) throw;
  }
}
