// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title FractionalDomain
 * @dev ERC-1155 contract for fractional domain ownership
 */
contract FractionalDomain is ERC1155, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    
    Counters.Counter private _domainIds;
    
    struct Domain {
        string name;
        address originalOwner;
        uint256 totalShares;
        uint256 purchasePrice;
        bool isActive;
        mapping(address => uint256) revenueShares;
    }
    
    // Domain ID => Domain
    mapping(uint256 => Domain) public domains;
    
    // Domain name => Domain ID
    mapping(string => uint256) public domainNameToId;
    
    // Domain ID => Total revenue collected
    mapping(uint256 => uint256) public domainRevenue;
    
    // Domain ID => Address => Revenue claimed
    mapping(uint256 => mapping(address => uint256)) public revenueClaimed;
    
    event DomainFractionalized(
        uint256 indexed domainId,
        string domainName,
        uint256 totalShares,
        uint256 purchasePrice
    );
    
    event RevenueDeposited(uint256 indexed domainId, uint256 amount);
    event RevenueClaimed(uint256 indexed domainId, address indexed claimer, uint256 amount);
    event SharesTransferred(uint256 indexed domainId, address indexed from, address indexed to, uint256 amount);
    
    constructor() ERC1155("https://api.domanzo.xyz/metadata/{id}.json") {}
    
    /**
     * @dev Fractionalize a domain into ERC-1155 tokens
     * @param domainName Name of the domain
     * @param totalShares Total number of shares to create
     * @param purchasePrice Original purchase price
     * @param shareholders Array of shareholder addresses
     * @param shareAmounts Array of share amounts for each shareholder
     */
    function fractionalizeDomain(
        string memory domainName,
        uint256 totalShares,
        uint256 purchasePrice,
        address[] memory shareholders,
        uint256[] memory shareAmounts
    ) external onlyOwner returns (uint256) {
        require(shareholders.length == shareAmounts.length, "Mismatched arrays");
        require(domainNameToId[domainName] == 0, "Domain already fractionalized");
        
        _domainIds.increment();
        uint256 domainId = _domainIds.current();
        
        Domain storage domain = domains[domainId];
        domain.name = domainName;
        domain.originalOwner = msg.sender;
        domain.totalShares = totalShares;
        domain.purchasePrice = purchasePrice;
        domain.isActive = true;
        
        domainNameToId[domainName] = domainId;
        
        // Mint shares to shareholders
        uint256 totalMinted = 0;
        for (uint256 i = 0; i < shareholders.length; i++) {
            require(shareAmounts[i] > 0, "Share amount must be > 0");
            _mint(shareholders[i], domainId, shareAmounts[i], "");
            domain.revenueShares[shareholders[i]] = shareAmounts[i];
            totalMinted += shareAmounts[i];
        }
        
        require(totalMinted == totalShares, "Total shares mismatch");
        
        emit DomainFractionalized(domainId, domainName, totalShares, purchasePrice);
        
        return domainId;
    }
    
    /**
     * @dev Deposit revenue for a fractionalized domain
     * @param domainId ID of the domain
     */
    function depositRevenue(uint256 domainId) external payable {
        require(domains[domainId].isActive, "Domain not active");
        require(msg.value > 0, "Must deposit some revenue");
        
        domainRevenue[domainId] += msg.value;
        
        emit RevenueDeposited(domainId, msg.value);
    }
    
    /**
     * @dev Claim revenue share for a domain
     * @param domainId ID of the domain
     */
    function claimRevenue(uint256 domainId) external nonReentrant {
        Domain storage domain = domains[domainId];
        require(domain.isActive, "Domain not active");
        
        uint256 userShares = balanceOf(msg.sender, domainId);
        require(userShares > 0, "No shares owned");
        
        uint256 totalRevenue = domainRevenue[domainId];
        uint256 userShare = (totalRevenue * userShares) / domain.totalShares;
        uint256 alreadyClaimed = revenueClaimed[domainId][msg.sender];
        uint256 claimable = userShare - alreadyClaimed;
        
        require(claimable > 0, "No revenue to claim");
        
        revenueClaimed[domainId][msg.sender] = userShare;
        
        (bool success, ) = payable(msg.sender).call{value: claimable}("");
        require(success, "Transfer failed");
        
        emit RevenueClaimed(domainId, msg.sender, claimable);
    }
    
    /**
     * @dev Get claimable revenue for an address
     * @param domainId ID of the domain
     * @param account Address to check
     */
    function getClaimableRevenue(uint256 domainId, address account) external view returns (uint256) {
        Domain storage domain = domains[domainId];
        if (!domain.isActive) return 0;
        
        uint256 userShares = balanceOf(account, domainId);
        if (userShares == 0) return 0;
        
        uint256 totalRevenue = domainRevenue[domainId];
        uint256 userShare = (totalRevenue * userShares) / domain.totalShares;
        uint256 alreadyClaimed = revenueClaimed[domainId][account];
        
        return userShare > alreadyClaimed ? userShare - alreadyClaimed : 0;
    }
    
    /**
     * @dev Get domain details
     * @param domainId ID of the domain
     */
    function getDomainInfo(uint256 domainId) external view returns (
        string memory name,
        address originalOwner,
        uint256 totalShares,
        uint256 purchasePrice,
        bool isActive,
        uint256 totalRevenue
    ) {
        Domain storage domain = domains[domainId];
        return (
            domain.name,
            domain.originalOwner,
            domain.totalShares,
            domain.purchasePrice,
            domain.isActive,
            domainRevenue[domainId]
        );
    }
    
    /**
     * @dev Override to track share transfers
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        super.safeTransferFrom(from, to, id, amount, data);
        
        Domain storage domain = domains[id];
        if (domain.isActive) {
            domain.revenueShares[from] -= amount;
            domain.revenueShares[to] += amount;
            
            emit SharesTransferred(id, from, to, amount);
        }
    }
    
    /**
     * @dev Update metadata URI
     */
    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }
}
