// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title CommunityDeal
 * @dev Smart contract for community-funded domain purchases
 * Integrates with DOMA's native fractionalization on Doma Chain
 */
contract CommunityDeal is ReentrancyGuard, Ownable {
    
    enum DealStatus {
        ACTIVE,
        FUNDED,
        EXECUTED,
        CANCELLED,
        REFUNDED
    }
    
    struct Deal {
        string domainName;
        address creator;
        uint256 targetPrice;
        uint256 minContribution;
        uint256 maxParticipants;
        uint256 currentAmount;
        uint256 participantCount;
        uint256 deadline;
        DealStatus status;
        bool purchased;
        uint256 domainTokenId; // DOMA domain ownership token ID
        address fractionalTokenAddress; // ERC-20 fractional token address from DOMA
    }
    
    struct Participant {
        uint256 contribution;
        bool refunded;
        uint256 shares;
    }
    
    // Deal ID counter
    uint256 private _dealIdCounter;
    
    // Deal ID => Deal
    mapping(uint256 => Deal) public deals;
    
    // Deal ID => Participant address => Participant
    mapping(uint256 => mapping(address => Participant)) public participants;
    
    // Deal ID => Array of participant addresses
    mapping(uint256 => address[]) public dealParticipants;
    
    // DOMA Ownership Token contract (ERC-721)
    IERC721 public domaOwnershipToken;
    
    // DOMA Fractionalization contract address
    address public domaFractionalization;
    
    // Governance voting
    mapping(uint256 => mapping(bytes32 => uint256)) public proposalVotes; // dealId => proposalHash => votes
    mapping(uint256 => mapping(bytes32 => mapping(address => bool))) public hasVoted; // dealId => proposalHash => voter => voted
    
    event DealCreated(
        uint256 indexed dealId,
        string domainName,
        address indexed creator,
        uint256 targetPrice,
        uint256 deadline
    );
    
    event ContributionMade(
        uint256 indexed dealId,
        address indexed contributor,
        uint256 amount
    );
    
    event DealFunded(uint256 indexed dealId, uint256 totalAmount);
    event DealExecuted(uint256 indexed dealId, uint256 tokenId, address fractionalToken);
    event DealCancelled(uint256 indexed dealId);
    event RefundProcessed(uint256 indexed dealId, address indexed participant, uint256 amount);
    event VoteCast(uint256 indexed dealId, bytes32 indexed proposalHash, address indexed voter, uint256 shares);
    event DomainPurchased(uint256 indexed dealId, uint256 tokenId);
    
    constructor(address _domaOwnershipToken, address _domaFractionalization) {
        domaOwnershipToken = IERC721(_domaOwnershipToken);
        domaFractionalization = _domaFractionalization;
    }
    
    /**
     * @dev Create a new community deal
     * @param domainName Name of the domain to purchase
     * @param targetPrice Target price in wei
     * @param minContribution Minimum contribution per participant
     * @param maxParticipants Maximum number of participants
     * @param durationInDays Duration of the deal in days
     */
    function createDeal(
        string memory domainName,
        uint256 targetPrice,
        uint256 minContribution,
        uint256 maxParticipants,
        uint256 durationInDays
    ) external returns (uint256) {
        require(targetPrice > 0, "Target price must be > 0");
        require(minContribution > 0, "Min contribution must be > 0");
        require(maxParticipants > 1, "Max participants must be > 1");
        require(durationInDays > 0 && durationInDays <= 90, "Invalid duration");
        
        _dealIdCounter++;
        uint256 dealId = _dealIdCounter;
        
        Deal storage deal = deals[dealId];
        deal.domainName = domainName;
        deal.creator = msg.sender;
        deal.targetPrice = targetPrice;
        deal.minContribution = minContribution;
        deal.maxParticipants = maxParticipants;
        deal.currentAmount = 0;
        deal.participantCount = 0;
        deal.deadline = block.timestamp + (durationInDays * 1 days);
        deal.status = DealStatus.ACTIVE;
        deal.purchased = false;
        
        emit DealCreated(dealId, domainName, msg.sender, targetPrice, deal.deadline);
        
        return dealId;
    }
    
    /**
     * @dev Contribute to a community deal
     * @param dealId ID of the deal
     */
    function contribute(uint256 dealId) external payable nonReentrant {
        Deal storage deal = deals[dealId];
        
        require(deal.status == DealStatus.ACTIVE, "Deal not active");
        require(block.timestamp < deal.deadline, "Deal expired");
        require(msg.value >= deal.minContribution, "Below minimum contribution");
        require(deal.currentAmount + msg.value <= deal.targetPrice, "Exceeds target price");
        
        Participant storage participant = participants[dealId][msg.sender];
        
        // If new participant
        if (participant.contribution == 0) {
            require(deal.participantCount < deal.maxParticipants, "Max participants reached");
            deal.participantCount++;
            dealParticipants[dealId].push(msg.sender);
        }
        
        participant.contribution += msg.value;
        deal.currentAmount += msg.value;
        
        emit ContributionMade(dealId, msg.sender, msg.value);
        
        // Check if deal is fully funded
        if (deal.currentAmount >= deal.targetPrice) {
            deal.status = DealStatus.FUNDED;
            emit DealFunded(dealId, deal.currentAmount);
        }
    }
    
    /**
     * @dev Mark domain as purchased after buying through DOMA marketplace
     * @param dealId ID of the deal
     * @param tokenId The DOMA ownership token ID
     */
    function markDomainPurchased(uint256 dealId, uint256 tokenId) external nonReentrant {
        Deal storage deal = deals[dealId];
        
        require(deal.status == DealStatus.FUNDED, "Deal not funded");
        require(msg.sender == deal.creator || msg.sender == owner(), "Not authorized");
        require(!deal.purchased, "Already purchased");
        
        deal.domainTokenId = tokenId;
        deal.purchased = true;
        
        emit DomainPurchased(dealId, tokenId);
    }
    
    /**
     * @dev Fractionalize the purchased domain using DOMA's fractionalization
     * This should be called after the domain NFT is transferred to this contract
     * and approved to DOMA fractionalization contract
     * @param dealId ID of the deal
     * @param fractionalTokenAddress Address of the ERC-20 fractional token created by DOMA
     */
    function setFractionalToken(uint256 dealId, address fractionalTokenAddress) external {
        Deal storage deal = deals[dealId];
        
        require(deal.purchased, "Domain not purchased");
        require(msg.sender == deal.creator || msg.sender == owner(), "Not authorized");
        require(deal.fractionalTokenAddress == address(0), "Already set");
        
        deal.fractionalTokenAddress = fractionalTokenAddress;
        deal.status = DealStatus.EXECUTED;
        
        // Record shares for governance
        address[] memory shareholders = dealParticipants[dealId];
        for (uint256 i = 0; i < shareholders.length; i++) {
            address participant = shareholders[i];
            uint256 contribution = participants[dealId][participant].contribution;
            // Share percentage based on contribution
            participants[dealId][participant].shares = (contribution * 10000) / deal.targetPrice;
        }
        
        emit DealExecuted(dealId, deal.domainTokenId, fractionalTokenAddress);
    }
    
    /**
     * @dev Cancel a deal (only if not funded or expired)
     * @param dealId ID of the deal
     */
    function cancelDeal(uint256 dealId) external {
        Deal storage deal = deals[dealId];
        
        require(
            msg.sender == deal.creator || msg.sender == owner(),
            "Not authorized"
        );
        require(
            deal.status == DealStatus.ACTIVE,
            "Cannot cancel this deal"
        );
        require(
            block.timestamp >= deal.deadline || deal.currentAmount == 0,
            "Deal active with contributions"
        );
        
        deal.status = DealStatus.CANCELLED;
        
        emit DealCancelled(dealId);
    }
    
    /**
     * @dev Request refund from a cancelled or expired deal
     * @param dealId ID of the deal
     */
    function refund(uint256 dealId) external nonReentrant {
        Deal storage deal = deals[dealId];
        Participant storage participant = participants[dealId][msg.sender];
        
        require(
            deal.status == DealStatus.CANCELLED ||
            (deal.status == DealStatus.ACTIVE && block.timestamp >= deal.deadline),
            "Refund not available"
        );
        require(participant.contribution > 0, "No contribution to refund");
        require(!participant.refunded, "Already refunded");
        
        uint256 refundAmount = participant.contribution;
        participant.refunded = true;
        
        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "Refund transfer failed");
        
        emit RefundProcessed(dealId, msg.sender, refundAmount);
    }
    
    /**
     * @dev Vote on a governance proposal
     * @param dealId ID of the deal
     * @param proposalHash Hash of the proposal
     */
    function vote(uint256 dealId, bytes32 proposalHash) external {
        Deal storage deal = deals[dealId];
        
        require(deal.status == DealStatus.EXECUTED, "Deal not executed");
        require(deal.fractionalized, "Not fractionalized");
        require(!hasVoted[dealId][proposalHash][msg.sender], "Already voted");
        
        uint256 shares = participants[dealId][msg.sender].shares;
        require(shares > 0, "No shares owned");
        
        proposalVotes[dealId][proposalHash] += shares;
        hasVoted[dealId][proposalHash][msg.sender] = true;
        
        emit VoteCast(dealId, proposalHash, msg.sender, shares);
    }
    
    /**
     * @dev Get deal details
     * @param dealId ID of the deal
     */
    function getDealInfo(uint256 dealId) external view returns (
        string memory domainName,
        address creator,
        uint256 targetPrice,
        uint256 currentAmount,
        uint256 participantCount,
        uint256 deadline,
        DealStatus status,
        bool purchased,
        uint256 domainTokenId,
        address fractionalTokenAddress
    ) {
        Deal storage deal = deals[dealId];
        return (
            deal.domainName,
            deal.creator,
            deal.targetPrice,
            deal.currentAmount,
            deal.participantCount,
            deal.deadline,
            deal.status,
            deal.purchased,
            deal.domainTokenId,
            deal.fractionalTokenAddress
        );
    }
    
    /**
     * @dev Get participant info
     * @param dealId ID of the deal
     * @param participant Address of participant
     */
    function getParticipantInfo(uint256 dealId, address participant) external view returns (
        uint256 contribution,
        bool refunded,
        uint256 shares
    ) {
        Participant storage p = participants[dealId][participant];
        return (p.contribution, p.refunded, p.shares);
    }
    
    /**
     * @dev Get all participants for a deal
     * @param dealId ID of the deal
     */
    function getDealParticipants(uint256 dealId) external view returns (address[] memory) {
        return dealParticipants[dealId];
    }
    
    /**
     * @dev Get vote count for a proposal
     * @param dealId ID of the deal
     * @param proposalHash Hash of the proposal
     */
    function getProposalVotes(uint256 dealId, bytes32 proposalHash) external view returns (uint256) {
        return proposalVotes[dealId][proposalHash];
    }
    
    /**
     * @dev Emergency withdraw (owner only, for stuck funds)
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance");
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }
    
    /**
     * @dev Update DOMA contract addresses
     */
    function setDomaContracts(address _domaOwnershipToken, address _domaFractionalization) external onlyOwner {
        domaOwnershipToken = IERC721(_domaOwnershipToken);
        domaFractionalization = _domaFractionalization;
    }
    
    /**
     * @dev Withdraw pooled funds to purchase domain (only creator or owner)
     * @param dealId ID of the deal
     * @param amount Amount to withdraw for purchase
     */
    function withdrawForPurchase(uint256 dealId, uint256 amount) external nonReentrant {
        Deal storage deal = deals[dealId];
        
        require(deal.status == DealStatus.FUNDED, "Deal not funded");
        require(msg.sender == deal.creator || msg.sender == owner(), "Not authorized");
        require(amount <= deal.currentAmount, "Insufficient funds");
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");
    }
    
    receive() external payable {}
}
