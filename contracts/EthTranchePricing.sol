pragma solidity ^0.4.11;

import "./PricingStrategy.sol";
import "./Crowdsale.sol";
import "./SafeMathLib.sol";
import './Ownable.sol';

/// @dev Tranche based pricing with special support for pre-ico deals.
///      Implementing "first price" tranches, meaning, that if byers order is
///      covering more than one tranche, the price of the lowest tranche will apply
///      to the whole order.
contract EthTranchePricing is PricingStrategy, Ownable {

  uint public constant MAX_TRANCHES = 10;
 
 
  // This contains all pre-ICO addresses, and their prices (weis per token)
  mapping (address => uint) public preicoAddresses;

  /**
  * Define pricing schedule using tranches.
  */

  struct Tranche {
      // Amount in weis when this tranche becomes active
      uint amount;
      // How many tokens per wei you will get while t5his tranche is active
      uint price;
  }

  // Store tranches in a fixed array, so that it can be seen in a blockchain explorer
  // Tranche 0 is always (0, 0)
  // (TODO: change this when we confirm dynamic arrays are explorable)
  Tranche[10] public tranches;

  // How many active tranches we have
  uint public trancheCount;

  /// @dev Contruction, creating a list of tranches
  /// @param _tranches uint[] tranches Pairs of (start amount, price)
  function EthTranchePricing(uint[] _tranches) {
    // [ 0, 666666666666666,
    //   3000000000000000000000, 769230769230769,
    //   5000000000000000000000, 909090909090909,
    //   8000000000000000000000, 952380952380952,
    //   2000000000000000000000, 1000000000000000 ]
    // Need to have tuples, length check
    require(!(_tranches.length % 2 == 1 || _tranches.length >= MAX_TRANCHES*2));
  
    trancheCount = _tranches.length / 2;
    uint highestAmount = 0;
    for(uint i=0; i<_tranches.length/2; i++) {
      tranches[i].amount = _tranches[i*2];
      tranches[i].price = _tranches[i*2+1];
      // No invalid steps
      require(!((highestAmount != 0) && (tranches[i].amount <= highestAmount)));
     
      highestAmount = tranches[i].amount;
    }

    // We need to start from zero, otherwise we blow up our deployment
    require(tranches[0].amount == 0);

    // Last tranche price must be zero, terminating the crowdale
    require(tranches[trancheCount-1].price == 0);
  }

  // /// @dev This is invoked once for every pre-ICO address, set pricePerToken
  // ///      to 0 to disable
  // /// @param preicoAddress PresaleFundCollector address
  // /// @param pricePerToken How many weis one token cost for pre-ico investors
  // function setPreicoAddress(address preicoAddress, uint tokenAmount, uint weiAmount) //Take Wei Amount
  //   public
  //   onlyOwner
  // {
  //   preicoAddresses[preicoAddress] = pricePerToken;
  // }
 
  /// @dev Iterate through tranches. You reach end of tranches when price = 0
  /// @return tuple (time, price)
  function getTranche(uint n) public constant returns (uint, uint) {
    return (tranches[n].amount, tranches[n].price);
  }

  function getFirstTranche() private constant returns (Tranche) {
    return tranches[0];
  }

  function getLastTranche() private constant returns (Tranche) {
    return tranches[trancheCount-1];
  }

  function getPricingStartsAt() public constant returns (uint) {
    return getFirstTranche().amount;
  }

  function getPricingEndsAt() public constant returns (uint) {
    return getLastTranche().amount;
  }

  function isSane(address _crowdsale) public constant returns(bool) {
    // Our tranches are not bound by time, so we can't really check are we sane
    // so we presume we are ;)
    // In the future we could save and track raised tokens, and compare it to
    // the Crowdsale contract.
    return true;
  }

  /// @dev Get the current tranche or bail out if we are not in the tranche periods.
  /// @param weiRaised total amount of weis raised, for calculating the current tranche
  /// @return {[type]} [description]
  function getCurrentTranche(uint weiRaised) private constant returns (Tranche) {
    uint i;
    for(i=0; i < tranches.length; i++) {
      if(weiRaised < tranches[i].amount) {
        return tranches[i-1];
      }
    }
  }

  /// @dev Get the current price.
  /// @param weiRaised total amount of weis raised, for calculating the current tranche
  /// @return The current price or 0 if we are outside trache ranges
  function getCurrentPrice(uint weiRaised) public constant returns (uint result) {
    return getCurrentTranche(weiRaised).price;
  }

  /// @dev Calculate the current price for buy in amount.
  function calculatePrice(uint value, uint weiRaised, uint tokensSold, address reciever, uint decimals) public constant returns (uint) {

    uint multiplier = 10 ** decimals;

    // This investor is coming through pre-ico
    // if(preicoAddresses[reciever] > 0) {
    //   return safeMul(value, multiplier) / preicoAddresses[msgSender];
    // }

    uint price = getCurrentPrice(weiRaised);
    
    return safeMul(value, multiplier) / price;
  }

  function() payable {
    throw; // No money on this contract
  }

}
