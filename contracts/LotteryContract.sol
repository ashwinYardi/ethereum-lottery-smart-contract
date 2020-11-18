pragma solidity ^0.6.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract LotteryContract is VRFConsumerBase {
    using SafeMath for uint256;
    using Address for address;

    struct LotteryConfig {
        uint256 numOfWinners;
        uint256 playersLimit;
        uint256 registrationAmount;
        uint256 adminFeePercentage;
        address lotteryTokenAddress;
        uint256 randomSeed;
    }

    address[] lotteryPlayers;
    address adminAddress;
    enum LotteryStatus {NOTSTARTED, INPROGRESS, CLOSED}
    mapping(address => bool) winnerAddresses;
    uint256[] winnerIndexes;
    uint256 totalLotteryPool;

    IERC20 lotteryToken;
    LotteryStatus public lotteryStatus;
    LotteryConfig lotteryConfig;

    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 internal randomResult;
    bool internal areWinnersGenerated;

    event MaxParticipationCompleted(address indexed _from);
    event WinnersGenerated();
    event LotterySettled();
    event LotteryStarted();
    event LotteryReset();

    constructor()
        public
        VRFConsumerBase(
            0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9, // VRF Coordinator
            0xa36085F69e2889c224210F603D836748e7dC0088 // LINK Token
        )
    {
        adminAddress = msg.sender;
        lotteryStatus = LotteryStatus.NOTSTARTED;
        totalLotteryPool = 0;
        keyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        fee = 0.1 * 10**18; // 0.1 LINK
        areWinnersGenerated = false;
    }

    function getRandomNumber(uint256 userProvidedSeed)
        internal
        returns (bytes32 requestId)
    {
        require(
            LINK.balanceOf(address(this)) >= fee,
            "Not enough LINK - fill contract with faucet"
        );
        return requestRandomness(keyHash, fee, userProvidedSeed);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        randomResult = randomness;
        for (uint256 i = 0; i < lotteryConfig.numOfWinners; i++) {
            uint256 winningIndex = randomResult % lotteryConfig.playersLimit;
            address userAddress = lotteryPlayers[winningIndex];
            while (winnerAddresses[userAddress]) {
                randomResult = randomResult + getRandomNumberBlockchain(i);
                winningIndex = randomResult % lotteryConfig.playersLimit;
                userAddress = lotteryPlayers[winningIndex];
            }
            winnerAddresses[userAddress] = true;
            winnerIndexes.push(winningIndex);
            randomResult = randomResult + getRandomNumberBlockchain(i);
        }
        areWinnersGenerated = true;
        emit WinnersGenerated();
        settleLottery();
    }

    function setLotteryRules(
        uint256 numOfWinners,
        uint256 playersLimit,
        uint256 registrationAmount,
        uint256 adminFeePercentage,
        address lotteryTokenAddress,
        uint256 randomSeed
    ) public {
        require(
            msg.sender == adminAddress,
            "Starting the Lottery requires Admin Access"
        );
        require(
            lotteryStatus == LotteryStatus.NOTSTARTED,
            "Error: An existing lottery is in progress"
        );
        lotteryConfig = LotteryConfig(
            numOfWinners,
            playersLimit,
            registrationAmount,
            adminFeePercentage,
            lotteryTokenAddress,
            randomSeed
        );
        lotteryStatus = LotteryStatus.INPROGRESS;
        lotteryToken = IERC20(lotteryTokenAddress);
        emit LotteryStarted();
    }

    function enterLottery() public returns (bool) {
        require(
            lotteryPlayers.length < lotteryConfig.playersLimit,
            "Max Participation for the Lottery Reached"
        );
        require(
            lotteryStatus == LotteryStatus.INPROGRESS,
            "The Lottery is not started or closed"
        );
        require(
            lotteryToken.allowance(msg.sender, address(this)) >=
                lotteryConfig.registrationAmount,
            "Contract is not allowed to spend this"
        );
        lotteryPlayers.push(msg.sender);
        lotteryToken.transferFrom(
            msg.sender,
            address(this),
            lotteryConfig.registrationAmount
        );
        totalLotteryPool += lotteryConfig.registrationAmount;
        if (lotteryPlayers.length == lotteryConfig.playersLimit) {
            emit MaxParticipationCompleted(msg.sender);
            getRandomNumber(lotteryConfig.randomSeed);
        }
        return true;
    }

    function settleLottery() internal {
        require(
            areWinnersGenerated,
            "Lottery Configuration still in progress. Ploease try in a short while"
        );
        require(
            lotteryStatus == LotteryStatus.INPROGRESS,
            "The Lottery is not started or closed"
        );
        uint256 adminFees = (totalLotteryPool *
            lotteryConfig.adminFeePercentage) / 100;
        uint256 winnersPool = (totalLotteryPool - adminFees) /
            lotteryConfig.numOfWinners;
        for (uint256 i = 0; i < lotteryConfig.numOfWinners; i++) {
            address userAddress = lotteryPlayers[winnerIndexes[i]];
            lotteryToken.transfer(userAddress, winnersPool);
        }
        lotteryToken.transfer(adminAddress, adminFees);
        lotteryStatus = LotteryStatus.CLOSED;
        emit LotterySettled();
    }

    function getRandomNumberBlockchain(uint256 offset)
        internal
        view
        returns (uint256)
    {
        bytes32 offsetBlockhash = blockhash(block.number - offset);
        return uint256(offsetBlockhash);
    }

    function resetLottery() public {
        require(
            msg.sender == adminAddress,
            "Resetting the Lottery requires Admin Access"
        );
        require(
            lotteryStatus == LotteryStatus.CLOSED,
            "Lottery Still in Progress"
        );
        delete lotteryConfig;
        delete randomResult;
        delete lotteryStatus;
        delete totalLotteryPool;
        for (uint256 i = 0; i < lotteryPlayers.length; i++) {
            winnerAddresses[lotteryPlayers[i]] = false;
        }
        areWinnersGenerated = false;
        delete winnerIndexes;
        delete lotteryPlayers;
        emit LotteryReset();
    }
}
