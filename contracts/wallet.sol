pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import { ContractUpgradeableSigner } from './contract-upgradeable-signer.sol';

contract Wallet is ContractUpgradeableSigner {
  constructor () ContractUpgradeableSigner(msg.sender) public {
  }
  function notify(
    bytes32 checkHash,
    address sender,
    address recipient,
    uint amount,
    bool isRemedy
  )
    public
    returns (bool)
  {
  }
}