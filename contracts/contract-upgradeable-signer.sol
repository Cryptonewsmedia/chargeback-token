pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import { Signer } from './signer.sol';

contract ContractUpgradeableSigner {
  address signer;
  constructor (address _signer) public {
    _signer = signer;
  }

  mapping (bytes32 => mapping (address => bool)) public agreed;
  function setHashVerificationSignature(
    bytes32 hashed,
    bool set,
    address consumer
  )
    internal
    returns (address)
  {
    if(set == true){
      agreed[hashed][consumer] = set;
    }
    else {
      delete agreed[hashed][consumer];
    }
  }
  function setHashVerificationWithSignature(
    bytes32 hashed,
    bytes memory signature,
    bool set,
    address consumer
  )
    public
    returns (bool)
  {
    Signer _signer = Signer(signer);
    if(_signer.verifySignature(hashed, signature)){
      if(set == true){
        agreed[hashed][consumer] = set;
      }
      else {
        delete agreed[hashed][consumer];
      }
    }
    return set;
  }
  function consumeSignature(
    bytes32 hashed
  )
    public
    returns (bool)
  {
    if(agreed[hashed][msg.sender] == true){
      delete agreed[hashed][msg.sender];
      return true;
    } else if (agreed[hashed][address(0)] == true){
      delete agreed[hashed][address(0)];
      return true;
    }
    return false;
  }
  function upgradeSigner(
    address newSigner,
    bytes memory signature
  )
    public
    returns (address)
  {
    Signer oldSigner = Signer(signer);
    if(oldSigner.verifyUpgrade(newSigner, signature)){
      signer = newSigner;
      return newSigner;
    }
    return signer;
  }
}