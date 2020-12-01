// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

import "./CircuitBreaker.sol";
import "../node_modules/openzeppelin-solidity/contracts/payment/PullPayment.sol";

contract BountyApp is PullPayment, CircuitBreaker{

  address private owner;

  constructor() public {
    owner = msg.sender;
  }

  enum BountyStage {
    Open,
    Closed
  }

  struct Bounty {
    uint32 bountyId;
    address creator;
    string desc;
    uint256 bountyAmt;
    BountyStage bountyStage;
  }

  mapping (uint32 => Bounty) bounties;
  uint32 numBounties;

  struct Solution {
    uint32 solutionId;
    address hunter;
    string answer;
    bool accepted;
  }

  mapping (uint32 => mapping(uint32 => Solution)) solutions;
  mapping (uint32 => uint32) numSolutions;

  /// CRUD on Bounties ///

  /** 
   * @dev Create a Bounty
   * @param desc The Bounty Problem Description
   * @param bountyAmt The Bounty Reward Amount in Wei
   */
  function createBounty(string desc, uint256 bountyAmt) external 
  stopInEmergency amountIsNotZero(bountyAmt) bountiesCountDoesNotOverflow returns (uint32) {
    bounties[numBounties] = Bounty(numBounties, msg.sender, desc, bountyAmt, BountyStage.Open);
    numBounties++;
    return numBounties;
  }
  
  /**
   * @dev Get the Bounty by bountyId 
   * @param bountyId index of the bounty
   */
  function getBounty(uint32 bountyId) external view validateBountiesIndex(bountyId) returns (address, string, uint256, uint32) {
    return (bounties[bountyId].creator, bounties[bountyId].desc, bounties[bountyId].bountyAmt, uint32(bounties[bountyId].bountyStage));
  }

  /**
   * @dev Get the number of bounties created
   */
  function returnBountiesCount() external view returns (uint32) {
    return numBounties;
  }

  /// CRUD on Solutions ///

  /**
   * @dev Create a solution for given bounty
   * @param bountyId index of the bounty
   * @param answer the solution proposed for the bounty
   */
  function createSolution(uint32 bountyId, string answer) external stopInEmergency solutionsCountDoesNotOverflow(bountyId) returns (uint32) {
    solutions[bountyId][numSolutions[bountyId]] = Solution(numSolutions[bountyId], msg.sender, answer, false);
    numSolutions[bountyId]++;
    return numSolutions[bountyId];
  }

  /**
   * @dev Get the solution proposed for a given bounty by index
   * @param bountyId index of the given bounty
   * @param solutionId index of the solution
   */
  function getSolution(uint32 bountyId, uint32 solutionId) external view 
  validateSolutionsIndex(bountyId, solutionId) returns (address, string, bool) {
    return (solutions[bountyId][solutionId].hunter, solutions[bountyId][solutionId].answer, solutions[bountyId][solutionId].accepted);
  }

  /**
   * @dev Get the number of solutions submitted for a given bounty
   * @param bountyId index of the given bounty
   */
  function returnSolutionsCount(uint32 bountyId) external view validateBountiesIndex(bountyId) returns (uint32) {
    return numSolutions[bountyId];
  }

  
  /**
   * @dev Get the solution to be awarded by index
   * @param bountyId index of the bounty
   * @param solutionId index of the solution
   */
  function getSolutionToBeAwarded(uint32 bountyId, uint32 solutionId) external view validateBountiesIndex(bountyId)
  validateSolutionsIndex(bountyId, solutionId) returns (address, uint256) {
    return(solutions[bountyId][solutionId].hunter, bounties[bountyId].bountyAmt);
  }


  /**
   * @dev Perform all the actions to be expected when a solution is accepted
   * @param bountyId index of the bounty
   * @param solutionId index of the solution
   */
  function untrustedAcceptSolution(uint32 bountyId, uint32 solutionId) external payable
  validateBountiesIndex(bountyId) validateSolutionsIndex(bountyId, solutionId) stopInEmergency 
  onlyOpenBounty(bountyId) isCreator(bountyId) solutionNotAccepted(bountyId, solutionId) {
    bounties[bountyId].bountyStage = BountyStage.Closed;
    solutions[bountyId][solutionId].accepted = true;
    untrustedCreditTransfer(solutions[bountyId][solutionId].hunter, bounties[bountyId].bountyAmt);
  }

  ///MODIFIERS///

  modifier onlyOwner() {
    require(msg.sender == owner, "Sender is not owner");
    _;
  }

  modifier isCreator(uint32 bountyId) {
    require(msg.sender == bounties[bountyId].creator, "Sender is not Bounty creator");
    _;
  }

  modifier solutionNotAccepted(uint32 bountyId, uint32 solutionId) {
    require(solutions[bountyId][solutionId].accepted == false, "Solution is already accepted");
    _;
  }

  modifier onlyOpenBounty(uint32 bountyId) {
    require(bounties[bountyId].bountyStage == BountyStage.Open, "Bounty is closed");
    _;
  }

  modifier amountIsNotZero(uint256 amount) {
    require(amount != 0, "Amount is zero");
    _;
  }

  modifier bountiesCountDoesNotOverflow {
    require((numBounties + 1) > numBounties, "No. of bounties is more than uint32 can support");
    _;
  }

  modifier solutionsCountDoesNotOverflow (uint32 bountyId) {
    require((numSolutions[bountyId] + 1) > numSolutions[bountyId], "No. of solutions is more than uint32 can support");
    _;
  }

  modifier validateBountiesIndex (uint32 bountyId) {
    require(bountyId < numBounties, "Array index out of bounds");
    _;
  }

  modifier validateSolutionsIndex (uint32 bountyId, uint32 solutionId) {
    require(solutionId < numSolutions[bountyId], "Array index out of bounds");
    _;
  }

  modifier withdrawAmtIsNotZero (address bountyHunterAddress) {
    require(untrustedCheckBountyWinnings(bountyHunterAddress)!=0, "Nothing to withdraw");
    _;
  }


/// Bounty Payment Operations ///

  /**
   * @dev Credit the bounty Reward to the bounty hunter in an escrow
   * @param dest address of the bounty hunter to be credited
   * @param amount amount of Wei to be credited to the bounty hunter
   */
  function untrustedCreditTransfer(address dest, uint256 amount) public payable stopInEmergency amountIsNotZero(amount) {
    asyncTransfer(dest, amount);
  }

  /**
   * @dev Withdraw the bounty reward winnings credited from the escrow account
   */
  function untrustedWithdrawBountyReward() external withdrawAmtIsNotZero(msg.sender) {
    withdrawPayments();
  }

  /**
   * @dev Check the bounty winnings credited in the escrow 
   * @param hunterAddress Address of the bounty hunter
   */
  function untrustedCheckBountyWinnings(address hunterAddress) public view returns(uint256) {
    return payments(hunterAddress);
  }

}
