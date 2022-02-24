// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Cubo.sol";
import "./Dai.sol";

// CuboDao V1.1
contract CuboDaoV11 {
  uint public totalNodes;
  address [] public cuboNodesAddresses;

  Cubo public cuboAddress;
  Dai public daiAddress;
  address private owner;
  uint public cuboInterestRatePercent;

  struct Account {
    bool exists;
    uint nanoCount;
    uint miniCount;
    uint kiloCount;
    uint megaCount;
    uint gigaCount;
    uint interestAccumulated;
  }

  mapping(address => Account) public accounts;

  // 0.5%, 0.6%, 0.7%, 0.8%, 1% /day
  uint [] public nodeMultiplers = [1, 3, 7, 16, 100];

  constructor(Cubo _cuboAddress, Dai _daiAddress) {
    owner = msg.sender;
    cuboAddress = _cuboAddress;
    daiAddress = _daiAddress;
    cuboInterestRatePercent = 1 * 100;
  }

  function setupAccountForMigration(address _address, uint _nanoCount, uint _miniCount, uint _kiloCount, uint _megaCount, uint _gigaCount, uint _interestAccumulated) public {
    require(_address != address(0), "_address is address 0");
    require(msg.sender == owner, 'Only owner can create a node.');

    if(!accounts[_address].exists){
      Account memory account = Account(true, _nanoCount, _miniCount, _kiloCount, _megaCount, _gigaCount, _interestAccumulated);
      cuboNodesAddresses.push(_address);
      totalNodes += _nanoCount + _miniCount + _kiloCount + _megaCount + _gigaCount;
      accounts[_address] = account;
    }
  }

  // totalNodes getter
  function getTotalNodes() public view returns(uint) {
    return totalNodes;
  }

  // cuboNodesAddresses getters
  function getAccountsLength() public view returns(uint) {
    return cuboNodesAddresses.length;
  }

  function getAccountsAddressForIndex(uint _index) public view returns(address) {
    return cuboNodesAddresses[_index];
  }

  // accounts getter
  function getAccount(address _address) public view returns(uint, uint, uint, uint, uint, uint) {
    Account memory acc = accounts[_address];
    return(acc.nanoCount, acc.miniCount, acc.kiloCount, acc.megaCount, acc.gigaCount, acc.interestAccumulated);
  }

  function mintNode(address _address, uint _cuboAmount, uint _daiAmount, uint _nodeType) public {
    require(_address != address(0), "_address is address 0");
    require(msg.sender == _address, 'Only user can create a node.');
    require(_nodeType >= 0 && _nodeType <= 4, 'Invalid node type');

    Account memory account;

    if(accounts[_address].exists){
      account = accounts[_address];
    }
    else{
      account = Account(true, 0, 0, 0, 0, 0, 0);
      cuboNodesAddresses.push(_address);
    }

    if(_nodeType == 0){
      require(_cuboAmount >= 100 * 10 ** 18, 'You must provide at least 100 CUBO for the LP token');
      require(_daiAmount >= 100 * 10 ** 18, 'You must provide at least 100 DAI for the LP token');
      account.nanoCount++;
    }
    else if(_nodeType == 1){
      require(_cuboAmount >= 250 * 10 ** 18, 'You must provide at least 250 CUBO for the LP token');
      require(_daiAmount >= 250 * 10 ** 18, 'You must provide at least 250 DAI for the LP token');
      account.miniCount++;
    }
    else if(_nodeType == 2){
      require(_cuboAmount >= 500 * 10 ** 18, 'You must provide at least 500 CUBO for the LP token');
      require(_daiAmount >= 500 * 10 ** 18, 'You must provide at least 500 DAI for the LP token');
      account.kiloCount++;
    }
    else if(_nodeType == 3){
      require(_cuboAmount >= 1000 * 10 ** 18, 'You must provide at least 1000 CUBO for the LP token');
      require(_daiAmount >= 1000 * 10 ** 18, 'You must provide at least 1000 DAI for the LP token');
      account.megaCount++;
    }
    else if(_nodeType == 4){
      require(_cuboAmount >= 5000 * 10 ** 18, 'You must provide at least 5000 CUBO for the LP token');
      require(_daiAmount >= 5000 * 10 ** 18, 'You must provide at least 5000 DAI for the LP token');
      account.gigaCount++;
    }
    totalNodes++;
    accounts[_address] = account;

    cuboAddress.transferFrom(_address, address(this), _cuboAmount);
    daiAddress.transferFrom(_address, address(this), _daiAmount);
  }

  function widthrawInterest(address _to) public {
    require(_to != address(0), "_to is address 0");
    require(msg.sender == _to, 'Only user can widthraw its own funds.');
    require(accounts[_to].interestAccumulated > 0, 'Interest accumulated must be greater than zero.');

    uint amount = accounts[_to].interestAccumulated;
    accounts[_to].interestAccumulated = 0;

    cuboAddress.transfer(_to, amount);
  }

  // _indexTo not included
  function payInterest(uint _indexFrom, uint _indexTo) public {
    require(msg.sender == owner, 'You must be the owner to run this.');

    uint i;
    for(i = _indexFrom; i < _indexTo; i++){
      address a = cuboNodesAddresses[i];
      Account memory acc = accounts[a];
      uint interestAccumulated;

      // add cuboInterestRatePercent/100 CUBO per node that address has
      interestAccumulated = (acc.nanoCount * nodeMultiplers[0] * cuboInterestRatePercent * 10 ** 18) / 100;
      interestAccumulated += (acc.miniCount * nodeMultiplers[1] * cuboInterestRatePercent * 10 ** 18) / 100;
      interestAccumulated += (acc.kiloCount * nodeMultiplers[2] * cuboInterestRatePercent * 10 ** 18) / 100;
      interestAccumulated += (acc.megaCount * nodeMultiplers[3] * cuboInterestRatePercent * 10 ** 18) / 100;
      interestAccumulated += (acc.gigaCount * nodeMultiplers[4] * cuboInterestRatePercent * 10 ** 18) / 100;

      acc.interestAccumulated += interestAccumulated;

      accounts[a] = acc;
    }
  }

  // runs daily at 2AM
  function balancePool() public {
    require(msg.sender == owner, 'You must be the owner to run this.');

    uint poolAmount = cuboAddress.balanceOf(address(this)) / 10 ** 18;
    uint runwayInDays = poolAmount/((totalNodes * cuboInterestRatePercent * nodeMultiplers[4]) / 100);
    if(runwayInDays > 900){
      uint newTotalTokens = (365 * cuboInterestRatePercent * totalNodes * nodeMultiplers[4]) / 100; // 365 is the desired runway
      uint amountToBurn = poolAmount - newTotalTokens;
      cuboAddress.burn(amountToBurn * 10 ** 18);
    }
    else if(runwayInDays < 360){
      uint newTotalTokens = (365 * cuboInterestRatePercent * totalNodes * nodeMultiplers[4]) / 100; // 365 is the desired runway
      uint amountToMint = newTotalTokens - poolAmount;
      cuboAddress.mint(amountToMint * 10 ** 18);
    }
  }

  function changeInterestRate(uint _newRate) public {
    require(msg.sender == owner, 'You must be the owner to run this.');
    cuboInterestRatePercent = _newRate;
  }

  function transferCubo(address _address, uint amount) public {
    require(_address != address(0), "_address is address 0");
    require(msg.sender == owner, 'You must be the owner to run this.');
    cuboAddress.transfer(_address, amount);
  }

  function transferDai(address _address, uint amount) public {
    require(_address != address(0), "_address is address 0");
    require(msg.sender == owner, 'You must be the owner to run this.');
    daiAddress.transfer(_address, amount);
  }

  function awardNode(address _address, uint _nodeType) public {
    require(_address != address(0), "_address is address 0");
    require(msg.sender == owner, 'You must be the owner to run this.');

    Account memory account;

    if(accounts[_address].exists){
      account = accounts[_address];
    }
    else{
      account = Account(true, 0, 0, 0, 0, 0, 0);
      cuboNodesAddresses.push(_address);
    }

    if(_nodeType == 0){
      account.nanoCount++;
    }
    else if(_nodeType == 1){
      account.miniCount++;
    }
    else if(_nodeType == 2){
      account.kiloCount++;
    }
    else if(_nodeType == 3){
      account.megaCount++;
    }
    else if(_nodeType == 4){
      account.gigaCount++;
    }
    totalNodes++;
    accounts[_address] = account;
  }
}