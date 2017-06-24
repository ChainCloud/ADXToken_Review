pragma solidity ^0.4.11;

// QUESTIONS FOR AUDITORS:
// - Considering we inherit from VestedToken, how much does that hit at our gas price?
// - Ensure max supply is 100,000,000
// - Ensure that even if not totalSupply is sold, tokens would still be transferrable after (we will up to totalSupply by creating adEx tokens)

// Instead of minting/minting period, implement the following changes
// #1) ADX contract knows his owner (AdExContrib) - minter
// #2) ADX contract allows transfer() when "from" is owner (AdExContrib), even if non transferrable period
// #3) non transferrable period only affected by now > end
// #4) all tokens 100,000,000 created at constructor of token sale, with owner being AdExContrib

// vesting: 365 days, 365 days / 4 vesting

import "../zeppelin-solidity/contracts/SafeMath.sol";
import "../zeppelin-solidity/contracts/token/VestedToken.sol";

contract ADX is VestedToken {
  //FIELDS
  string public name = "AdEx";
  string public symbol = "ADX";
  uint public decimals = 4;

  //ASSIGNED IN INITIALIZATION
  uint public endMintingTime; // Timestamp after which no more tokens can be created
  address public minter; // address of the account which may mint new tokens

  //MODIFIERS
  //Can only be called by contribution contract.
  modifier only_minter {
    if (msg.sender != minter) throw;
    _;
  }

  // Can only be called if the `crowdfunder` is allowed to mint tokens. Any
  // time before ` endMintingTime`.
  modifier when_mintable {
    if (now >= endMintingTime) throw;
    _;
  }

  // Initialization contract assigns address of crowdfund contract and end time.
  function ADX(address _minter, uint _endMintingTime) {
    endMintingTime = _endMintingTime;
    minter = _minter;
  }

  // Create new tokens when called by the crowdfund contract.
  // Only callable before the end time.
  function createToken(address _recipient, uint _value)
    when_mintable
    only_minter
    returns (bool o_success)
  {
    balances[_recipient] += _value;
    totalSupply += _value;
    return true;
  }

  // Transfer amount of tokens from sender account to recipient.
  // Only callable after the crowd fund end date, except if we're minter
  function transfer(address _to, uint _value)
  {
    // Token is not transferrable during the crowdsale (minting), EXCEPT if we're the minter (crowdsale contract)
    if (! (now >= endMintingTime || msg.sender == minter)) throw;
    super.transfer(_to, _value);
  }

  // Transfer amount of tokens from a specified address to a recipient.
  // Only callable after the crowd fund end date.
  function transferFrom(address _from, address _to, uint _value)
  {
    if (now < endMintingTime) throw;
    super.transferFrom(_from, _to, _value);
  }
}

contract AdExContrib {
  //FIELDS

  //CONSTANTS
  //Time limits
  uint public constant STAGE_ONE_TIME_END = 24 hours; // first day bonus
  uint public constant STAGE_TWO_TIME_END = 1 weeks; // first week bonus
  uint public constant STAGE_THREE_TIME_END = 4 weeks;
  
  // Decimals
  // WARNING: Must be synced up with ADX.decimals
  uint private constant DECIMALS = 10000;

  //Prices of ADX
  uint public constant PRICE_STANDARD    = 900*DECIMALS; // ADX received per one ETH; MAX_SUPPLY / (valuation / ethPrice)
  uint public constant PRICE_STAGE_ONE   = PRICE_STANDARD * 100/30;
  uint public constant PRICE_STAGE_TWO   = PRICE_STANDARD * 100/15;
  uint public constant PRICE_STAGE_THREE = PRICE_STANDARD;
  uint public constant PRICE_PREBUY      = PRICE_STANDARD * 100/30; // 20% bonus will be given from illiquid tokens-

  //ADX Token Limits
  //uint public constant MAX_SUPPLY =        100000000*DECIMALS;
  uint public constant ALLOC_TEAM =         16000000*DECIMALS; // team + advisors
  uint public constant ALLOC_BOUNTIES =      2000000*DECIMALS;
  uint public constant ALLOC_WINGS =         2000000*DECIMALS;
  uint public constant ALLOC_CROWDSALE =    80000000*DECIMALS;
  uint public constant PREBUY_PORTION_MAX = 32 * DECIMALS * PRICE_PREBUY;
  
  //ASSIGNED IN INITIALIZATION
  //Start and end times
  uint public publicStartTime; // Time in seconds public crowd fund starts.
  uint public privateStartTime; // Time in seconds when pre-buy can purchase up to 31250 ETH worth of ADX;
  uint public publicEndTime; // Time in seconds crowdsale ends
  
  //Special Addresses
  address public prebuyAddress; // Address used by pre-buy
  address public multisigAddress; // Address to which all ether flows.
  address public adexAddress; // Address to which ALLOC_TEAM, ALLOC_BOUNTIES, ALLOC_WINGS  is (ultimately) sent to.
  address public ownerAddress; // Address of the contract owner. Can halt the crowdsale.
  
  //Contracts
  ADX public ADXToken; // External token contract hollding the ADX
  
  //Running totals
  uint public etherRaised; // Total Ether raised.
  uint public ADXSold; // Total ADX created
  uint public prebuyPortionTotal; // Total of Tokens purchased by pre-buy. Not to exceed PREBUY_PORTION_MAX.
  
  //booleans
  bool public halted; // halts the crowd sale if true.

  //FUNCTION MODIFIERS

  //Is currently in the period after the private start time and before the public start time.
  modifier is_pre_crowdfund_period() {
    if (now >= publicStartTime || now < privateStartTime) throw;
    _;
  }

  //Is currently the crowdfund period
  modifier is_crowdfund_period() {
    if (now < publicStartTime || now >= publicEndTime) throw;
    _;
  }

  // Is completed
  modifier is_crowdfund_completed() {
    if (now < publicEndTime && ADXSold < ALLOC_CROWDSALE) throw;
    _;
  }

  //May only be called by pre-buy
  modifier only_prebuy() {
    if (msg.sender != prebuyAddress) throw;
    _;
  }

  //May only be called by the owner address
  modifier only_owner() {
    if (msg.sender != ownerAddress) throw;
    _;
  }

  //May only be called if the crowdfund has not been halted
  modifier is_not_halted() {
    if (halted) throw;
    _;
  }

  // EVENTS
  event PreBuy(uint _amount);
  event Buy(address indexed _recipient, uint _amount);


  // FUNCTIONS

  //Initialization function. Deploys ADXToken contract assigns values, to all remaining fields, creates first entitlements in the ADX Token contract.
  function AdExContrib(
    address _prebuy,
    address _multisig,
    address _adex,
    uint _publicStartTime,
    uint _privateStartTime
  ) {
    ownerAddress = msg.sender;
    publicStartTime = _publicStartTime;
    privateStartTime = _privateStartTime;
    publicEndTime = _publicStartTime + 4 weeks;
    prebuyAddress = _prebuy;
    multisigAddress = _multisig;
    adexAddress = _adex;
    ADXToken = new ADX(this, publicEndTime);
    ADXToken.createToken(adexAddress, ALLOC_BOUNTIES);
    ADXToken.createToken(adexAddress, ALLOC_WINGS);
    ADXToken.createToken(ownerAddress, ALLOC_TEAM); // this will be converted into vested token and sent to adexAddress by calling grantVested
    ADXToken.createToken(this, ALLOC_CROWDSALE); // this will be transfer()-ed by the smart contract, i.e. minter in the ADX context
    // no more createToken from now on
  }

  //May be used by owner of contract to halt crowdsale and no longer except ether.
  function toggleHalt(bool _halted)
    only_owner
  {
    halted = _halted;
  }

  //constant function returns the current ADX price.
  function getPriceRate()
      constant
      returns (uint o_rate)
  {
      uint delta = SafeMath.sub(now, publicStartTime);

      if (delta > STAGE_TWO_TIME_END) return PRICE_STAGE_THREE;
      if (delta > STAGE_ONE_TIME_END) return PRICE_STAGE_TWO;

      return (PRICE_STAGE_ONE);
  }
  
  // Given the rate of a purchase and the remaining tokens in this tranche, it
  // will throw if the sale would take it past the limit of the tranche.
  // It executes the purchase for the appropriate amount of tokens, which
  // involves adding it to the total, minting ADX tokens and stashing the
  // ether.
  // Returns `amount` in scope as the number of ADX tokens that it will
  // purchase.
  function processPurchase(uint _rate, uint _remaining)
    internal
    returns (uint o_amount)
  {
    o_amount = SafeMath.div(SafeMath.mul(msg.value, _rate), 1 ether);
    if (o_amount > _remaining) throw;
    if (!multisigAddress.send(msg.value)) throw;
    ADXToken.transfer(msg.sender, o_amount);
    ADXSold += o_amount;
    etherRaised += msg.value;
  }

  //Special Function can only be called by pre-buy and only during the pre-crowdsale period.
  //Allows the purchase of up to 125000 Ether worth of ADX Tokens.
  function preBuy()
    payable
    is_pre_crowdfund_period
    only_prebuy
    is_not_halted
  {
    uint amount = processPurchase(PRICE_PREBUY, SafeMath.sub(PREBUY_PORTION_MAX, prebuyPortionTotal));
    prebuyPortionTotal += amount;
    PreBuy(amount);
  }

  //Default function called by sending Ether to this address with no arguments.
  //Results in creation of new ADX Tokens if transaction would not exceed hard limit of ADX Token.
  function()
    payable
    is_crowdfund_period
    is_not_halted
  {
    uint amount = processPurchase(getPriceRate(), SafeMath.sub(ALLOC_CROWDSALE, ADXSold));
    Buy(msg.sender, amount);
  }

  // To be called at the end of crowdfund period
  function grantVested()
    is_crowdfund_completed
    only_owner
    is_not_halted
  {
    // Grant tokens allocated for the team
    ADXToken.grantVestedTokens(
      adexAddress, ALLOC_TEAM,
      uint64(now), uint64(now) + ( 3 * 30 days ), uint64(now) + ( 12 * 30 days ), 
      false, false
    );
  }

  // Used for easier testing
  function balanceOf(address _addr) constant public returns (uint) {
    return ADXToken.balanceOf(_addr);
  }

  //failsafe drain
  function drain()
    only_owner
  {
    if (!ownerAddress.send(this.balance)) throw;
  }
}