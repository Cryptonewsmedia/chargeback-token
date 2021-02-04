pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import { ContractUpgradeableSigner } from './contract-upgradeable-signer.sol';
import { DataStructures } from './data-structures.sol';

contract Network is ContractUpgradeableSigner {
  uint constant public maxTransfersInProgress = 10;
  uint constant public transferTimeBlocks = 100;

  constructor () ContractUpgradeableSigner(msg.sender) public {
  }

  uint public transfersInProgress;
  mapping (bytes32 => DataStructures.Status) public transfers;

  uint constant public remedyTimeoutBlocks = 100;

  uint constant public maxTransfer = 1000;
  uint constant public minTransfer = 1;
  uint constant public feeNumber = 1;
  uint constant public feeBasisPoints = 10;
  address constant public recoverableTokenContract = address(0x0);

  modifier onlyLinkedRecoverableTokenContract {
    require(msg.sender == recoverableTokenContract, "Only Linked Recoverable Token Contract May Call This");
    _;
  }
  // getTransfer returns the transfer from the transfers mapping
  function getTransfer(
    bytes32 checkHash
  )
    public
    view
    returns (DataStructures.Status memory)
  {
    return transfers[checkHash];
  }
  // isAcceptableTransfer checks to see if this transfer may submitted to the network
  function isAcceptableTransfer(
    DataStructures.Quote memory quote
  )
    public
    view
    returns (bool)
  {
    if(quote.blockNumberMin > block.number){
      return false;
    }
    if(quote.blockNumberMax < block.number && quote.blockNumberMax != 0){
      return false;
    }
    if(maxTransfersInProgress > transfersInProgress + 1){
      return false;
    }
    if(maxTransfer < quote.amount){
      return false;
    }
    if(minTransfer > quote.amount){
      return false;
    }
    return true;
  }
  // getFee returns the fee based on sending an amount on the given network
  function getFee(
    uint amount
  )
    public
    pure
    returns (uint predictedFee)
  {
    predictedFee = (amount * feeBasisPoints / 10000) + feeNumber;
    return predictedFee;
  }
  // post transfer adds a transfer to the network
  function postTransfer(
    bytes32 hashedCheck
  )
    public
    onlyLinkedRecoverableTokenContract
    returns (bool)
  {
    require(maxTransfersInProgress > transfersInProgress, "Too many transfer in progress");
    require(transfers[hashedCheck].blockStarted == 0, "Transfer aleady started");
    transfers[hashedCheck].blockStarted = block.number;
    ++transfers[hashedCheck].nonce;
    ++transfersInProgress;
    return true;
  }
  // update the transfer status
  function updateTransferStatus(
    bytes32 hashedCheck,
    DataStructures.TransferState updatedState
  )
    public
    onlyLinkedRecoverableTokenContract
    returns (bool)
  {
    if(updatedState == DataStructures.TransferState.Closed){
      --transfersInProgress;
      delete transfers[hashedCheck];
      return true;
    }
    ++transfers[hashedCheck].nonce;
    transfers[hashedCheck].state = updatedState;
    return false;
  }
  // closeNetwork()
  function notify(
    address, // _from,
    address, // _to,
    uint, // amount,
    bool // isRemedy
  )
    public
    onlyLinkedRecoverableTokenContract
    returns (bool)
  {
    return true;
  }
}