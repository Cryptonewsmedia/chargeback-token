pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import { ECDSA } from '../node_modules/openzeppelin-solidity/contracts/cryptography/ECDSA.sol';

contract Signer {
  function verifySignature(
    bytes32 hashed,
    bytes memory signature
  )
    public
    view
    returns (bool)
  {
    require (address(0) == ECDSA.recover(hashed, signature), "Signature Does Not Match");
    return true;
  }
  function verifyUpgrade(
    address newSigner,
    bytes memory signature
  )
    public
    view
    returns (bool)
  {
    bytes32 hashed = keccak256(abi.encode(newSigner));
    require(address(0) == ECDSA.recover(hashed, signature), "Old Signer Did Not Authorize Upgrade");
    return true;
  }
}
