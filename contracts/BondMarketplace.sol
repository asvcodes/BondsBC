// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title BondMarketplace
 * @notice Simplified MVP contract for listing and investing in decentralized bonds.
 * @dev This contract is intentionally simple for learning/demo purposes.
 */
contract BondMarketplace {
    struct Bond {
        uint256 id;
        address organization;
        string name;
        uint256 interestRate; // in %
        uint256 durationDays;
        uint256 totalFundingRequired; // wei
        uint256 amountRaised; // wei
        uint256 trustScore; // 0-100 (simple transparency-based score)
        uint256 createdAt;
        string[] fundUsageLogs;
        bool exists;
    }

    struct Investor {
        address investorAddress;
        mapping(uint256 => uint256) investments; // bondId => amount invested
        uint256[] investedBondIds;
        bool initialized;
    }

    uint256 public nextBondId;
    mapping(uint256 => Bond) private bonds;
    uint256[] private bondIds;
    mapping(address => Investor) private investors;

    event BondCreated(
        uint256 indexed bondId,
        address indexed organization,
        string name,
        uint256 interestRate,
        uint256 durationDays,
        uint256 totalFundingRequired
    );

    event Invested(
        uint256 indexed bondId,
        address indexed investor,
        uint256 amount,
        uint256 newAmountRaised
    );

    event FundUsageUpdated(
        uint256 indexed bondId,
        address indexed organization,
        string description,
        uint256 logCount
    );

    event TrustScoreUpdated(uint256 indexed bondId, uint256 newTrustScore);

    modifier bondMustExist(uint256 bondId) {
        require(bonds[bondId].exists, "Bond does not exist");
        _;
    }

    modifier onlyBondOrganization(uint256 bondId) {
        require(
            bonds[bondId].organization == msg.sender,
            "Only creator organization allowed"
        );
        _;
    }

    /**
     * @notice Create and list a new bond.
     */
    function createBond(
        string calldata name,
        uint256 interestRate,
        uint256 durationDays,
        uint256 totalFundingRequired
    ) external {
        require(bytes(name).length > 0, "Name is required");
        require(totalFundingRequired > 0, "Funding must be > 0");
        require(durationDays > 0, "Duration must be > 0");

        uint256 bondId = nextBondId;
        nextBondId++;

        Bond storage b = bonds[bondId];
        b.id = bondId;
        b.organization = msg.sender;
        b.name = name;
        b.interestRate = interestRate;
        b.durationDays = durationDays;
        b.totalFundingRequired = totalFundingRequired;
        b.amountRaised = 0;
        b.trustScore = 0;
        b.createdAt = block.timestamp;
        b.exists = true;

        bondIds.push(bondId);

        emit BondCreated(
            bondId,
            msg.sender,
            name,
            interestRate,
            durationDays,
            totalFundingRequired
        );
    }

    /**
     * @notice Add a fund usage update for a bond.
     * @dev Only the bond creator can call this.
     */
    function updateFundUsage(
        uint256 bondId,
        string calldata description
    ) external bondMustExist(bondId) onlyBondOrganization(bondId) {
        require(bytes(description).length > 0, "Description is required");

        Bond storage b = bonds[bondId];
        b.fundUsageLogs.push(description);

        emit FundUsageUpdated(
            bondId,
            msg.sender,
            description,
            b.fundUsageLogs.length
        );

        updateTrustScore(bondId);
    }

    /**
     * @notice Updates trust score based on transparency activity.
     * @dev Simple formula for MVP:
     *      - Base score: min(50, logsCount * 10)
     *      - Bonus if updated early: +10 if first update within 7 days of creation
     *      - Bonus for momentum: +2 per 10% funding progress (max +20)
     *      - Max score capped at 100
     */
    function updateTrustScore(
        uint256 bondId
    ) public bondMustExist(bondId) returns (uint256) {
        Bond storage b = bonds[bondId];

        uint256 logsCount = b.fundUsageLogs.length;
        uint256 base = logsCount * 10;
        if (base > 50) {
            base = 50;
        }

        uint256 earlyUpdateBonus = 0;
        if (logsCount > 0 && block.timestamp <= b.createdAt + 7 days) {
            earlyUpdateBonus = 10;
        }

        uint256 fundingProgressBonus = 0;
        if (b.totalFundingRequired > 0) {
            uint256 progressPercent = (b.amountRaised * 100) / b.totalFundingRequired;
            fundingProgressBonus = (progressPercent / 10) * 2;
            if (fundingProgressBonus > 20) {
                fundingProgressBonus = 20;
            }
        }

        uint256 newScore = base + earlyUpdateBonus + fundingProgressBonus;
        if (newScore > 100) {
            newScore = 100;
        }

        b.trustScore = newScore;
        emit TrustScoreUpdated(bondId, newScore);

        return newScore;
    }

    /**
     * @notice Invest ETH into a specific bond.
     */
    function investInBond(uint256 bondId) external payable bondMustExist(bondId) {
        Bond storage b = bonds[bondId];

        require(msg.value > 0, "Investment must be > 0");
        require(
            b.amountRaised + msg.value <= b.totalFundingRequired,
            "Investment exceeds funding target"
        );

        Investor storage inv = investors[msg.sender];
        if (!inv.initialized) {
            inv.investorAddress = msg.sender;
            inv.initialized = true;
        }

        if (inv.investments[bondId] == 0) {
            inv.investedBondIds.push(bondId);
        }

        inv.investments[bondId] += msg.value;
        b.amountRaised += msg.value;

        // Forward funds to organization (simplified behavior for MVP).
        (bool sent, ) = payable(b.organization).call{value: msg.value}("");
        require(sent, "Failed to transfer funds to organization");

        emit Invested(bondId, msg.sender, msg.value, b.amountRaised);

        updateTrustScore(bondId);
    }

    /**
     * @notice Returns summary arrays for all bonds.
     */
    function getAllBonds()
        external
        view
        returns (
            uint256[] memory ids,
            address[] memory organizations,
            string[] memory names,
            uint256[] memory interestRates,
            uint256[] memory durations,
            uint256[] memory totals,
            uint256[] memory raised,
            uint256[] memory trustScores
        )
    {
        uint256 count = bondIds.length;

        ids = new uint256[](count);
        organizations = new address[](count);
        names = new string[](count);
        interestRates = new uint256[](count);
        durations = new uint256[](count);
        totals = new uint256[](count);
        raised = new uint256[](count);
        trustScores = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            Bond storage b = bonds[bondIds[i]];
            ids[i] = b.id;
            organizations[i] = b.organization;
            names[i] = b.name;
            interestRates[i] = b.interestRate;
            durations[i] = b.durationDays;
            totals[i] = b.totalFundingRequired;
            raised[i] = b.amountRaised;
            trustScores[i] = b.trustScore;
        }
    }

    /**
     * @notice Returns complete details for one bond including usage logs.
     */
    function getBondDetails(
        uint256 bondId
    )
        external
        view
        bondMustExist(bondId)
        returns (
            uint256 id,
            address organization,
            string memory name,
            uint256 interestRate,
            uint256 durationDays,
            uint256 totalFundingRequired,
            uint256 amountRaised,
            uint256 trustScore,
            string[] memory fundUsageLogs
        )
    {
        Bond storage b = bonds[bondId];
        return (
            b.id,
            b.organization,
            b.name,
            b.interestRate,
            b.durationDays,
            b.totalFundingRequired,
            b.amountRaised,
            b.trustScore,
            b.fundUsageLogs
        );
    }

    function getTrustScore(uint256 bondId) external view bondMustExist(bondId) returns (uint256) {
        return bonds[bondId].trustScore;
    }

    /**
     * @notice Returns investor portfolio as bondId/amount arrays.
     */
    function getInvestorPortfolio(
        address investorAddress
    ) external view returns (uint256[] memory investedIds, uint256[] memory investedAmounts) {
        Investor storage inv = investors[investorAddress];
        uint256 count = inv.investedBondIds.length;

        investedIds = new uint256[](count);
        investedAmounts = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 bondId = inv.investedBondIds[i];
            investedIds[i] = bondId;
            investedAmounts[i] = inv.investments[bondId];
        }
    }
}