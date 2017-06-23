pragma solidity ^0.4.11;


// TODO:
// openzeppelin for everything up to ADX
// vested tokens (12m, 3m cliff)

// QUESTIONS FOR AUDITORS:
// Considering we inherit from VestedToken, how much does that hit at our gas price?
// Ensure max supply is 100,000,000
// Ensure that even if not totalSupply is sold, tokens would still be transferrable after (we will up to totalSupply by creating adEx tokens)

// https://github.com/OpenZeppelin/zeppelin-solidity/blob/v1.0.7/contracts/SafeMath.sol
/**
 * Math operations with safety checks
 */
library SafeMath {
  function mul(uint a, uint b) internal returns (uint) {
    uint c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint a, uint b) internal returns (uint) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint a, uint b) internal returns (uint) {
    assert(b <= a);
    return a - b;
  }

  function add(uint a, uint b) internal returns (uint) {
    uint c = a + b;
    assert(c >= a);
    return c;
  }

  function max64(uint64 a, uint64 b) internal constant returns (uint64) {
    return a >= b ? a : b;
  }

  function min64(uint64 a, uint64 b) internal constant returns (uint64) {
    return a < b ? a : b;
  }

  function max256(uint256 a, uint256 b) internal constant returns (uint256) {
    return a >= b ? a : b;
  }

  function min256(uint256 a, uint256 b) internal constant returns (uint256) {
    return a < b ? a : b;
  }

  function assert(bool assertion) internal {
    if (!assertion) {
      throw;
    }
  }
}


// https://github.com/OpenZeppelin/zeppelin-solidity/blob/v1.0.7/contracts/token/ERC20Basic.sol
/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20Basic {
  uint public totalSupply;
  function balanceOf(address who) constant returns (uint);
  function transfer(address to, uint value);
  event Transfer(address indexed from, address indexed to, uint value);
}


// https://github.com/OpenZeppelin/zeppelin-solidity/blob/v1.0.7/contracts/token/ERC20.sol
/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) constant returns (uint);
  function transferFrom(address from, address to, uint value);
  function approve(address spender, uint value);
  event Approval(address indexed owner, address indexed spender, uint value);
}


// https://github.com/OpenZeppelin/zeppelin-solidity/blob/v1.0.7/contracts/token/BasicToken.sol
/**
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances. 
 */
contract BasicToken is ERC20Basic {
  using SafeMath for uint;

  mapping(address => uint) balances;

  /**
   * @dev Fix for the ERC20 short address attack.
   */
  modifier onlyPayloadSize(uint size) {
     if(msg.data.length < size + 4) {
       throw;
     }
     _;
  }

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint _value) onlyPayloadSize(2 * 32) {
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of. 
  * @return An uint representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) constant returns (uint balance) {
    return balances[_owner];
  }

}

// https://github.com/OpenZeppelin/zeppelin-solidity/blob/v1.0.7/contracts/token/StandardToken.sol
/**
 * @title Standard ERC20 token
 *
 * @dev Implemantation of the basic standart token.
 * @dev https://github.com/ethereum/EIPs/issues/20
 * @dev Based on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 */
contract StandardToken is BasicToken, ERC20 {

  mapping (address => mapping (address => uint)) allowed;


  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint the amout of tokens to be transfered
   */
  function transferFrom(address _from, address _to, uint _value) onlyPayloadSize(3 * 32) {
    var _allowance = allowed[_from][msg.sender];

    // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
    // if (_value > _allowance) throw;

    balances[_to] = balances[_to].add(_value);
    balances[_from] = balances[_from].sub(_value);
    allowed[_from][msg.sender] = _allowance.sub(_value);
    Transfer(_from, _to, _value);
  }

  /**
   * @dev Aprove the passed address to spend the specified amount of tokens on beahlf of msg.sender.
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint _value) {

    // To change the approve amount you first have to reduce the addresses`
    //  allowance to zero by calling `approve(_spender, 0)` if it is not
    //  already 0 to mitigate the race condition described here:
    //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    if ((_value != 0) && (allowed[msg.sender][_spender] != 0)) throw;

    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
  }

  /**
   * @dev Function to check the amount of tokens than an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint specifing the amount of tokens still avaible for the spender.
   */
  function allowance(address _owner, address _spender) constant returns (uint remaining) {
    return allowed[_owner][_spender];
  }

}



// https://github.com/OpenZeppelin/zeppelin-solidity/blob/v1.0.7/contracts/token/LimitedTransferToken.sol
/**
 * @title LimitedTransferToken
 * @dev LimitedTransferToken defines the generic interface and the implementation to limit token 
 * transferability for different events. It is intended to be used as a base class for other token 
 * contracts. 
 * LimitedTransferToken has been designed to allow for different limiting factors,
 * this can be achieved by recursively calling super.transferableTokens() until the base class is 
 * hit. For example:
 *     function transferableTokens(address holder, uint64 time) constant public returns (uint256) {
 *       return min256(unlockedTokens, super.transferableTokens(holder, time));
 *     }
 * A working example is VestedToken.sol:
 * https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/token/VestedToken.sol
 */

contract LimitedTransferToken is ERC20 {

  /**
   * @dev Checks whether it can transfer or otherwise throws.
   */
  modifier canTransfer(address _sender, uint _value) {
   if (_value > transferableTokens(_sender, uint64(now))) throw;
   _;
  }

  /**
   * @dev Checks modifier and allows transfer if tokens are not locked.
   * @param _to The address that will recieve the tokens.
   * @param _value The amount of tokens to be transferred.
   */
  function transfer(address _to, uint _value) canTransfer(msg.sender, _value) {
    super.transfer(_to, _value);
  }

  /**
  * @dev Checks modifier and allows transfer if tokens are not locked.
  * @param _from The address that will send the tokens.
  * @param _to The address that will recieve the tokens.
  * @param _value The amount of tokens to be transferred.
  */
  function transferFrom(address _from, address _to, uint _value) canTransfer(_from, _value) {
    super.transferFrom(_from, _to, _value);
  }

  /**
   * @dev Default transferable tokens function returns all tokens for a holder (no limit).
   * @dev Overwriting transferableTokens(address holder, uint64 time) is the way to provide the 
   * specific logic for limiting token transferability for a holder over time.
   */
  function transferableTokens(address holder, uint64 time) constant public returns (uint256) {
    return balanceOf(holder);
  }
}

// https://github.com/OpenZeppelin/zeppelin-solidity/blob/710f77dfe1851d76351f347c622768842d5aece3/contracts/token/VestedToken.sol
/**
 * @title Vested token
 * @dev Tokens that can be vested for a group of addresses.
 */
contract VestedToken is StandardToken, LimitedTransferToken {

  uint256 MAX_GRANTS_PER_ADDRESS = 20;

  struct TokenGrant {
    address granter;     // 20 bytes
    uint256 value;       // 32 bytes
    uint64 cliff;
    uint64 vesting;
    uint64 start;        // 3 * 8 = 24 bytes
    bool revocable;
    bool burnsOnRevoke;  // 2 * 1 = 2 bits? or 2 bytes?
  } // total 78 bytes = 3 sstore per operation (32 per sstore)

  mapping (address => TokenGrant[]) public grants;

  event NewTokenGrant(address indexed from, address indexed to, uint256 value, uint256 grantId);

  /**
   * @dev Grant tokens to a specified address
   * @param _to address The address which the tokens will be granted to.
   * @param _value uint256 The amount of tokens to be granted.
   * @param _start uint64 Time of the beginning of the grant.
   * @param _cliff uint64 Time of the cliff period.
   * @param _vesting uint64 The vesting period.
   */
  function grantVestedTokens(
    address _to,
    uint256 _value,
    uint64 _start,
    uint64 _cliff,
    uint64 _vesting,
    bool _revocable,
    bool _burnsOnRevoke
  ) public {

    // Check for date inconsistencies that may cause unexpected behavior
    if (_cliff < _start || _vesting < _cliff) {
      throw;
    }

    if (tokenGrantsCount(_to) > MAX_GRANTS_PER_ADDRESS) throw;   // To prevent a user being spammed and have his balance locked (out of gas attack when calculating vesting).

    uint256 count = grants[_to].push(
                TokenGrant(
                  _revocable ? msg.sender : 0, // avoid storing an extra 20 bytes when it is non-revocable
                  _value,
                  _cliff,
                  _vesting,
                  _start,
                  _revocable,
                  _burnsOnRevoke
                )
              );

    transfer(_to, _value);

    NewTokenGrant(msg.sender, _to, _value, count - 1);
  }

  /**
   * @dev Revoke the grant of tokens of a specifed address.
   * @param _holder The address which will have its tokens revoked.
   * @param _grantId The id of the token grant.
   */
  function revokeTokenGrant(address _holder, uint256 _grantId) public {
    TokenGrant grant = grants[_holder][_grantId];

    if (!grant.revocable) { // Check if grant was revocable
      throw;
    }

    if (grant.granter != msg.sender) { // Only granter can revoke it
      throw;
    }

    address receiver = grant.burnsOnRevoke ? 0xdead : msg.sender;

    uint256 nonVested = nonVestedTokens(grant, uint64(now));

    // remove grant from array
    delete grants[_holder][_grantId];
    grants[_holder][_grantId] = grants[_holder][grants[_holder].length.sub(1)];
    grants[_holder].length -= 1;

    balances[receiver] = balances[receiver].add(nonVested);
    balances[_holder] = balances[_holder].sub(nonVested);

    Transfer(_holder, receiver, nonVested);
  }


  /**
   * @dev Calculate the total amount of transferable tokens of a holder at a given time
   * @param holder address The address of the holder
   * @param time uint64 The specific time.
   * @return An uint256 representing a holder's total amount of transferable tokens.
   */
  function transferableTokens(address holder, uint64 time) constant public returns (uint256) {
    uint256 grantIndex = tokenGrantsCount(holder);

    if (grantIndex == 0) return balanceOf(holder); // shortcut for holder without grants

    // Iterate through all the grants the holder has, and add all non-vested tokens
    uint256 nonVested = 0;
    for (uint256 i = 0; i < grantIndex; i++) {
      nonVested = SafeMath.add(nonVested, nonVestedTokens(grants[holder][i], time));
    }

    // Balance - totalNonVested is the amount of tokens a holder can transfer at any given time
    uint256 vestedTransferable = SafeMath.sub(balanceOf(holder), nonVested);

    // Return the minimum of how many vested can transfer and other value
    // in case there are other limiting transferability factors (default is balanceOf)
    return SafeMath.min256(vestedTransferable, super.transferableTokens(holder, time));
  }

  /**
   * @dev Check the amount of grants that an address has.
   * @param _holder The holder of the grants.
   * @return A uint256 representing the total amount of grants.
   */
  function tokenGrantsCount(address _holder) constant returns (uint256 index) {
    return grants[_holder].length;
  }

  /**
   * @dev Calculate amount of vested tokens at a specifc time.
   * @param tokens uint256 The amount of tokens grantted.
   * @param time uint64 The time to be checked
   * @param start uint64 A time representing the begining of the grant
   * @param cliff uint64 The cliff period.
   * @param vesting uint64 The vesting period.
   * @return An uint256 representing the amount of vested tokensof a specif grant.
   *  transferableTokens
   *   |                         _/--------   vestedTokens rect
   *   |                       _/
   *   |                     _/
   *   |                   _/
   *   |                 _/
   *   |                /
   *   |              .|
   *   |            .  |
   *   |          .    |
   *   |        .      |
   *   |      .        |
   *   |    .          |
   *   +===+===========+---------+----------> time
   *      Start       Clift    Vesting
   */
  function calculateVestedTokens(
    uint256 tokens,
    uint256 time,
    uint256 start,
    uint256 cliff,
    uint256 vesting) constant returns (uint256)
    {
      // Shortcuts for before cliff and after vesting cases.
      if (time < cliff) return 0;
      if (time >= vesting) return tokens;

      // Interpolate all vested tokens.
      // As before cliff the shortcut returns 0, we can use just calculate a value
      // in the vesting rect (as shown in above's figure)

      // vestedTokens = tokens * (time - start) / (vesting - start)
      uint256 vestedTokens = SafeMath.div(
                                    SafeMath.mul(
                                      tokens,
                                      SafeMath.sub(time, start)
                                      ),
                                    SafeMath.sub(vesting, start)
                                    );

      return vestedTokens;
  }

  /**
   * @dev Get all information about a specifc grant.
   * @param _holder The address which will have its tokens revoked.
   * @param _grantId The id of the token grant.
   * @return Returns all the values that represent a TokenGrant(address, value, start, cliff,
   * revokability, burnsOnRevoke, and vesting) plus the vested value at the current time.
   */
  function tokenGrant(address _holder, uint256 _grantId) constant returns (address granter, uint256 value, uint256 vested, uint64 start, uint64 cliff, uint64 vesting, bool revocable, bool burnsOnRevoke) {
    TokenGrant grant = grants[_holder][_grantId];

    granter = grant.granter;
    value = grant.value;
    start = grant.start;
    cliff = grant.cliff;
    vesting = grant.vesting;
    revocable = grant.revocable;
    burnsOnRevoke = grant.burnsOnRevoke;

    vested = vestedTokens(grant, uint64(now));
  }

  /**
   * @dev Get the amount of vested tokens at a specific time.
   * @param grant TokenGrant The grant to be checked.
   * @param time The time to be checked
   * @return An uint256 representing the amount of vested tokens of a specific grant at a specific time.
   */
  function vestedTokens(TokenGrant grant, uint64 time) private constant returns (uint256) {
    return calculateVestedTokens(
      grant.value,
      uint256(time),
      uint256(grant.start),
      uint256(grant.cliff),
      uint256(grant.vesting)
    );
  }

  /**
   * @dev Calculate the amount of non vested tokens at a specific time.
   * @param grant TokenGrant The grant to be checked.
   * @param time uint64 The time to be checked
   * @return An uint256 representing the amount of non vested tokens of a specifc grant on the 
   * passed time frame.
   */
  function nonVestedTokens(TokenGrant grant, uint64 time) private constant returns (uint256) {
    return grant.value.sub(vestedTokens(grant, time));
  }

  /**
   * @dev Calculate the date when the holder can trasfer all its tokens
   * @param holder address The address of the holder
   * @return An uint256 representing the date of the last transferable tokens.
   */
  function lastTokenIsTransferableDate(address holder) constant public returns (uint64 date) {
    date = uint64(now);
    uint256 grantIndex = grants[holder].length;
    for (uint256 i = 0; i < grantIndex; i++) {
      date = SafeMath.max64(grants[holder][i].vesting, date);
    }
  }
}


// END OF OpenZeppelin PORTION

// BEGIN OF ADX portion 

contract ADX is VestedToken {

  //FIELDS
  string public name = "AdEx";
  string public symbol = "ADX";
  uint public decimals = 4;

  //ASSIGNED IN INITIALIZATION
  uint public endMintingTime; //Timestamp after which no more tokens can be created
  uint public finalSupply; //Amount after which no more tokens can be created
  address public minter; //address of the account which may mint new tokens

  //MODIFIERS
  //Can only be called by contribution contract.
  modifier only_minter {
    if (msg.sender != minter) throw;
    _;
  }

  // Can only be called if (liquid) tokens may be transferred. Happens
  // immediately after `endMintingTime` or once the 'ALLOC_CROWDSALE' has been reached
  // This basically means 'after the crowdsale', as minting time is set to end of crowdsale
  modifier when_transferable {
    if ((now < endMintingTime && totalSupply < finalSupply)) throw;
    _;
  }

  // Can only be called if the `crowdfunder` is allowed to mint tokens. Any
  // time before ` endMintingTime`.
  modifier when_mintable {
    if (now >= endMintingTime) throw;
    _;
  }

  // Initialization contract assigns address of crowdfund contract and end time.
  function ADX(address _minter, uint _endMintingTime, uint _finalSupply) {
    endMintingTime = _endMintingTime;
    finalSupply = _finalSupply;
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
  // Only callable after the crowd fund end date.
  function transfer(address _from, uint _to)
    when_transferable
  {
    super.transfer(_from, _to);
  }

  // Transfer amount of tokens from a specified address to a recipient.
  // Only callable after the crowd fund end date.
  function transferFrom(address _from, address _to, uint _value)
    when_transferable
  {
    super.transferFrom(_from, _to, _value);
  }
}


contract AdExContrib {

  //FIELDS

  //CONSTANTS
  //Time limits
  uint public constant STAGE_ONE_TIME_END = 24 hours; // first day bonus
  uint public constant STAGE_TWO_TIME_END = 1 weeks;
  uint public constant STAGE_THREE_TIME_END = 2 weeks;
  uint public constant STAGE_FOUR_TIME_END = 4 weeks;
  

  // Decimals
  // WARNING: Must be synced up with ADX.decimals
  uint private constant DECIMALS = 10000;

  //Prices of ADX
  uint public constant PRICE_STANDARD    = 900*DECIMALS; // ADX received per one ETH; MAX_SUPPLY / (valuation / ethPrice)
  uint public constant PRICE_STAGE_ONE   = PRICE_STANDARD * 100/30;
  uint public constant PRICE_STAGE_TWO   = PRICE_STANDARD * 100/15;
  uint public constant PRICE_STAGE_THREE = PRICE_STANDARD;
  uint public constant PRICE_STAGE_FOUR  = PRICE_STANDARD;
  uint public constant PRICE_PREBUY      = PRICE_STANDARD * 100/30; // 20% bonus will be given from illiquid tokens-

  //ADX Token Limits
  uint public constant MAX_SUPPLY =        100000000*DECIMALS;
  uint public constant ALLOC_TEAM =         16000000*DECIMALS; // team + advisors
  uint public constant ALLOC_BOUNTIES =      2000000*DECIMALS;
  uint public constant ALLOC_WINGS =         2000000*DECIMALS;
  uint public constant ALLOC_CROWDSALE =    80000000*DECIMALS;
  uint public constant PREBUY_PORTION_MAX = 32 * DECIMALS * PRICE_PREBUY;
  
  //ASSIGNED IN INITIALIZATION
  //Start and end times
  uint public publicStartTime; //Time in seconds public crowd fund starts.
  uint public privateStartTime; //Time in seconds when pre-buy can purchase up to 31250 ETH worth of ADX;
  uint public publicEndTime; //Time in seconds crowdsale ends
  
  //Special Addresses
  address public prebuyAddress; //Address used by pre-buy
  address public multisigAddress; //Address to which all ether flows.
  address public adexAddress; //Address to which ALLOC_TEAM, ALLOC_BOUNTIES, ALLOC_WINGS  is (ultimately) sent to.
  address public ownerAddress; //Address of the contract owner. Can halt the crowdsale.
  
  //Contracts
  ADX public ADXToken; //External token contract hollding the ADX
  
  //Running totals
  uint public etherRaised; //Total Ether raised.
  uint public ADXSold; //Total ADX created
  uint public prebuyPortionTotal; //Total of Tokens purchased by pre-buy. Not to exceed PREBUY_PORTION_MAX.
  
  //booleans
  bool public halted; //halts the crowd sale if true.

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
    ADXToken = new ADX(this, publicEndTime, MAX_SUPPLY);
    ADXToken.createToken(adexAddress, ALLOC_BOUNTIES);
    ADXToken.createToken(adexAddress, ALLOC_WINGS);
    ADXToken.createToken(ownerAddress, ALLOC_TEAM); // this will be converted into vested token and sent to adexAddress by calling grantVested
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

      if (delta > STAGE_THREE_TIME_END) return PRICE_STAGE_FOUR;
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
    if (!ADXToken.createToken(msg.sender, o_amount)) throw;
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
    uint amount = processPurchase(PRICE_PREBUY, PREBUY_PORTION_MAX - prebuyPortionTotal);
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
    uint amount = processPurchase(getPriceRate(), ALLOC_CROWDSALE - ADXSold);
    Buy(msg.sender, amount);
  }

  // To be called at the end of crowdfund period
  function grantVested()
    is_crowdfund_completed
    only_owner
    is_not_halted
  {
    ADXToken.grantVestedTokens(
      adexAddress, ALLOC_TEAM,
      uint64(now), uint64(now) + ( 3 * 30 days ), uint64(now) + ( 12 * 30 days ), 
      false, false
    );
  }

  //failsafe drain
  function drain()
    only_owner
  {
    if (!ownerAddress.send(this.balance)) throw;
  }
}