pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import { RecoverableWallet } from './recoverable-wallet.sol';

contract RecoverableToken {

  struct Remedy {
    uint fundsToSender;
    uint fundsToRecipient;
    uint fundsToOther;
    address otherAddress;
    uint nonce;
    Check check;
  }
  function prepareRemedy(
    uint fundsToSender,
    uint fundsToRecipient,
    uint fundsToOther,
    address otherAddress,
    uint nonce,
    Check memory check
  )
    public
    pure
    returns (Remedy memory remedy)
  {
    remedy = Remedy({
      fundsToSender: fundsToSender,
      fundsToRecipient: fundsToRecipient,
      fundsToOther: fundsToOther,
      otherAddress: otherAddress,
      nonce: nonce,
      check: check
    });
    return remedy;
  }
  function hashRemedy(
    Remedy memory remedy
  )
    public
    pure
    returns (bytes32 hashed)
  {
    bytes memory encoded = abi.encodePacked(
      remedy.fundsToSender,
      remedy.fundsToRecipient,
      remedy.fundsToOther,
      remedy.otherAddress,
      remedy.nonce,
      hashCheck(remedy.check)
    );
    hashed = keccak256(encoded);
    return hashed;
  }
  function validateRemedy(
    Remedy memory remedy
  )
    public
    view
    returns (bytes32 hashedRemedy)
  {
    hashedRemedy = hashRemedy(remedy);

    RecoverableWallet senderWallet = RecoverableWallet(remedy.check.senderAddress);
    senderWallet.consumeSignature(hashedRemedy);

    RecoverableWallet recipientWallet = RecoverableWallet(remedy.check.recipientAddress);
    recipientWallet.consumeSignature(hashedRemedy);
    return hashedRemedy;
  }

  struct Check {
    bytes32 memoHash;
    uint amount;
    uint fee;
    uint blockNumberMax;
    uint blockNumberMin;
    address senderAddress;
    address recipientAddress;
    uint defaultRemedyFundsToSender;
    uint defaultRemedyFundsToRecipient;
    uint defaultRemedyFundsToOther;
    address defaultRemedyOtherAddress;
    uint transferTimeBlocks;
  }
  function prepareCheck(
    bytes memory memo,
    uint amount,
    uint fee,
    uint blockNumberMin,
    uint blockNumberMax,
    address senderAddress,
    address recipientAddress,
    uint defaultRemedyFundsToSender,
    uint defaultRemedyFundsToRecipient,
    uint defaultRemedyFundsToOther,
    address defaultRemedyOtherAddress,
    uint transferTimeBlocks
  )
    public
    pure
    returns (Check memory check)
  {
    check = Check({
      memoHash: keccak256(memo),
      amount: amount,
      fee: fee,
      blockNumberMin: blockNumberMin,
      blockNumberMax: blockNumberMax,
      senderAddress: senderAddress,
      recipientAddress: recipientAddress,
      defaultRemedyFundsToSender: defaultRemedyFundsToSender,
      defaultRemedyFundsToRecipient: defaultRemedyFundsToRecipient,
      defaultRemedyFundsToOther: defaultRemedyFundsToOther,
      defaultRemedyOtherAddress: defaultRemedyOtherAddress,
      transferTimeBlocks: transferTimeBlocks

    });
    return check;
  }
  function hashCheck(
    Check memory check
  )
    public
    pure
    returns (bytes32 hashed)
  {
    bytes memory encoded = abi.encodePacked(
      check.memoHash,
      check.amount,
      check.fee,
      check.blockNumberMin,
      check.blockNumberMax,
      check.senderAddress,
      check.recipientAddress,
      check.defaultRemedyFundsToSender,
      check.defaultRemedyFundsToRecipient,
      check.defaultRemedyFundsToOther,
      check.defaultRemedyOtherAddress,
      check.transferTimeBlocks
    );
    hashed = keccak256(encoded);
    return hashed;
  }
  // validates a check
  function validateCheck(
    Check memory check
  )
    public
    view
    returns (bytes32 hashedCheck)
  {
    require(!(check.blockNumberMin > block.number), "Block number too low to process check!");
    require(!(check.blockNumberMax < block.number) || check.blockNumberMax == 0, "Block number too high to process check!");
    bytes32 hashedQuoteFromCheck = hashQuote(check);

    RecoverableWallet senderWallet = RecoverableWallet(check.senderAddress);
    senderWallet.consumeSignature(hashedQuoteFromCheck);

    hashedCheck = hashCheck(check);

    RecoverableWallet recipientWallet = RecoverableWallet(check.recipientAddress);
    recipientWallet.consumeSignature(hashedCheck);
    return hashedCheck;
  }

  enum TransferStateUpdateRequestRequester {
    Sender,
    Recipient,
    Other
  }
  struct TransferStateUpdateRequest {
    Check check;
    TransferState fromState;
    TransferState updatedState;
    TransferStateUpdateRequestRequester requester;
    uint nonce;
  }
  enum TransferState {
    Open,
    Disputed,
    SenderRemedyAvailable,
    RecipientRemedyAvailable,
    BothRemedyAvailable,
    Closed
  }
  struct TransferStatus {
    TransferState state;
    uint blockStarted;
    uint nonce;
  }
  function prepareTransferStateUpdateRequest(
    TransferState updatedState,
    TransferState fromState,
    Check memory check,
    TransferStateUpdateRequestRequester requester,
    uint nonce
  )
    public
    pure
    returns (TransferStateUpdateRequest memory updateRequest)
  {
    updateRequest = TransferStateUpdateRequest({
      updatedState: updatedState,
      fromState: fromState,
      check: check,
      requester: requester,
      nonce: nonce
    });
    return updateRequest;
  }
  function hashTransferStateUpdateRequest(
    TransferStateUpdateRequest memory updateRequest
  )
    public
    pure
    returns (bytes32 hashed)
  {
    bytes memory encoded = abi.encodePacked(
      updateRequest.updatedState,
      updateRequest.fromState,
      hashCheck(updateRequest.check),
      updateRequest.requester,
      updateRequest.nonce
    );
    hashed = keccak256(encoded);
    return hashed;
  }

  mapping (bytes32 => TransferStatus) public transfers;
  mapping (address => uint) public balances;
  uint public pendingAmount;


  function startTransfer(
    address _from,
    address _to,
    uint amount
  )
    internal
    returns (bool)
  {
    require(balances[_from] >= amount, "Not enough funds");
    balances[_from] = balances[_from] - amount;
    pendingAmount += amount;
    return true;
  }
  function moveAmount(
    bytes32 checkHash,
    address _from,
    address _to,
    uint amount
    bool isRemedy
  )
    internal
  {
    pendingAmount -= amount;
    balances[_to] += amount;
    notify(
      checkHash,
      _from,
      _to,
      amount,
      isRemedy
    );
  }
  // update the transfer status
  function updateTransferStatus(
    bytes32 hashedCheck,
    TransferState updatedState
  )
    internal
    onlyLinkedRecoverableTokenContract
    returns (bool)
  {
    if(updatedState == TransferState.Closed){
      delete transfers[hashedCheck];
      return true;
    }
    ++transfers[hashedCheck].nonce;
    transfers[hashedCheck].state = updatedState;
    return false;
  }
  // post transfer adds a transfer
  function postTransfer(
    bytes32 hashedCheck
  )
    internal
  {
    require(transfers[hashedCheck].blockStarted == 0, "Transfer aleady started");
    transfers[hashedCheck].blockStarted = block.number;
    ++transfers[hashedCheck].nonce;
  }

  /*
    To send a check to someone else who doesn't have an address yet,
    1) Send a check to yourself then immediately sign a remedy which sends the money to that someone else.
    Sender can still recover funds if they want.
    2) Create a Recoverable Wallet, send funds to it, then move its signing method to the Recipient
    Sender cannot recover funds unless Recoverable Wallet Includes Provisions for Returning Control.
  */
  // startTransfer transfers funds should be called from after there is a valid check
  // submit check take a check, validates the signatures
  function submitCheck(
    Check memory check
  )
    public
    returns (bytes32)
  {
    bytes32 hashedCheck = validateCheck(check);
    RecoverableWallet senderWallet = RecoverableWallet(check.senderAddress);
    require(senderWallet.consumeSignature(hashedCheck) == true, "Sender signature cannot be consumed");
    postTransfer(hashedCheck); // we can instead post the transfer to blockNumberMax + transferTime
    startTransfer(
      check.senderAddress,
      check.recipientAddress,
      check.amount
    );
    return hashedCheck;
  }

  function requireValidTransfer(
    TransferStatus memory transfer,
    uint transferTimeInBlocks,
    TransferStateUpdateRequest memory updateRequest
  )
    public
    view
  {
    require(transfer.blockStarted != 0, "Transfer does not exist");
    require(transfer.state != TransferState.Closed, "Transfer is finished");
    require(transfer.state == updateRequest.fromState, "From State and Current State Divergent");
    require(transfer.nonce == updateRequest.nonce, "Nonce is Divergent");
    require(updateRequest.fromState != TransferState.Closed, "Cannot Update State From Closed");

    bytes32 hashedTransferStateUpdateRequest = hashTransferStateUpdateRequest(updateRequest);
    if(updateRequest.requester == TransferStateUpdateRequestRequester.Sender){
      if(updateRequest.fromState == TransferState.Open){
        require(
          updateRequest.updatedState == TransferState.Disputed ||
          updateRequest.updatedState == TransferState.Closed,
          "Sender Requested Invalid State Update From Open"
        );
      } else if(updateRequest.fromState == TransferState.Disputed){
        require(
          updateRequest.updatedState == TransferState.Open ||
          updateRequest.updatedState == TransferState.Closed,
          "Sender Requested Invalid State Update From Disputed"
        );
      }

      RecoverableWallet requesterWallet = RecoverableWallet(updateRequest.check.senderAddress);
      requesterWallet.consumeSignature(hashedTransferStateUpdateRequest);

    } else if(updateRequest.requester == TransferStateUpdateRequestRequester.Recipient){
      require(
        updateRequest.fromState == TransferState.Open,
        "Recipient Requested Invalid State Update From Disputed");

      if(updateRequest.fromState == TransferState.Open){
        require(
          updateRequest.updatedState == TransferState.Disputed ||
          (
            updateRequest.updatedState == TransferState.Closed &&
            transfer.blockStarted + transferTimeBlocks > block.number
          ),
          "Recipient Requested Invalid State Update From Open"
        );
      }

      RecoverableWallet requesterWallet = RecoverableWallet(updateRequest.check.recipientAddress);
      requesterWallet.consumeSignature(hashedTransferStateUpdateRequest);

    }
  }
  function updateTransfer(
    TransferStateUpdateRequest memory updateRequest,
    bytes memory signature
  )
    public
    returns (TransferState)
  {
    bytes32 hashedCheck = hashCheck(updateRequest.check);

    TransferStatus memory transfer = transfers[hashedCheck];
    requireValidTransfer(transfer, updateRequest.check.transferTimeInBlocks, updateRequest);

    if(updateRequest.updatedState == TransferState.Closed){
      // Closing the transaction
      updateTransferStatus(hashedCheck, TransferState.Closed);
      moveAmount(hashedCheck, updateRequest.check.senderAddress, updateRequest.check.recipientAddress, updateRequest.check.amount, false);
      delete transfers[hashedCheck];
      return TransferState.Closed;
    }
    else {
      updateTransferStatus(hashedCheck, updateRequest.updatedState);
      return updateRequest.updatedState;
    }
  }

  function tryProposedRemedy(
    Remedy memory remedy
  )
    public
    returns (TransferState)
  {
    bytes32 hashedCheck = hashCheck(remedy.check);
    TransferStatus memory transfer = transfers[hashedCheck];
    require(transfer.blockStarted != 0, "Transfer does not exist");
    require(transfer.state == TransferState.Disputed, "Transfer not Dispusted");
    // participants can sign remedies with nonce 0 if they wish for them to be always valid
    require(transfer.nonce == remedy.nonce || remedy.nonce == 0, "Nonce is Divergent");
    validateRemedy(remedy);
    updateTransferStatus(hashedCheck, TransferState.Closed);
    moveAmount(hashedCheck, remedy.check.senderAddress, remedy.check.recipientAddress, remedy.fundsToRecipient, true);
    moveAmount(hashedCheck, remedy.check.senderAddress, remedy.check.senderAddress, remedy.fundsToSender, true);
    moveAmount(hashedCheck, remedy.check.senderAddress, remedy.otherAddress, remedy.fundsToOther, true);
    delete transfers[hashedCheck];
    return TransferState.Closed;
  }

  function defaultRemedy(
    Check memory check
  )
    public
    returns (TransferState)
  {
    bytes32 hashedCheck = hashCheck(remedy.check);
    TransferStatus memory transfer = transfers[hashedCheck];
    require(transfer.blockStarted != 0, "Transfer does not exist");
    require(transfer.state == TransferState.Disputed, "Transfer not Dispusted");
    // participants can sign remedies with nonce 0 if they wish for them to be always valid
    updateTransferStatus(hashedCheck, TransferState.Closed);
    moveAmount(hashedCheck, check.senderAddress, check.recipientAddress, defaultRemedyFundsToRecipient, true);
    moveAmount(hashedCheck, check.senderAddress, check.senderAddress, defaultRemedyFundsToSender, true);
    moveAmount(hashedCheck, check.senderAddress, defaultRemedyOtherAddress, defaultRemedyFundsToOther, true);
    delete transfers[hashedCheck];
    return TransferState.Closed;
  }
}