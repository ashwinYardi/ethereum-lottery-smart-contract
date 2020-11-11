pragma solidity ^0.6.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

contract LotteryContract is VRFConsumerBase {
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
    address[] winners;
    uint256 totalLotteryPool;

    IERC20 lotteryToken;
    LotteryStatus lotteryStatus;
    LotteryConfig lotteryConfig;

    bytes32 internal keyHashVRF;
    uint256 internal feeVRF;
    uint256 public randomResult;

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
        keyHashVRF = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        feeVRF = 0.1 * 10**18; // 0.1 LINK
    }

    function getRandomNumberChainlink(uint256 userProvidedSeed)
        internal
        returns (bytes32 requestId)
    {
        require(
            LINK.balanceOf(address(this)) > feeVRF,
            "Not enough LINK - fill contract with faucet"
        );
        return requestRandomness(keyHashVRF, feeVRF, userProvidedSeed);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        randomResult = randomness;
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
            "Starting the Lottery requires Admin Access"
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
        //if chainlink takes time we go with blockchain approach
        randomResult = getRandomNumberBlockchain();
        // getRandomNumberChainlink(randomSeed);
    }

    function enterLottery() public returns (bool) {
        require(
            lotteryPlayers.length < lotteryConfig.playersLimit,
            "Max Participation for the Lottery Reached"
        );
        //add condition if address has already entered
        require(
            lotteryStatus == LotteryStatus.INPROGRESS,
            "The Lottery is Closed"
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
            settleLottery();
        }
        return true;
    }

    function settleLottery() internal {
        // require(msg.sender == adminAddress, "Requires Admin Access");
        uint256 adminFees = (totalLotteryPool *
            lotteryConfig.adminFeePercentage) / 100;
        uint256 winnersPool = (totalLotteryPool - adminFees) /
            lotteryConfig.numOfWinners;

        for (uint256 i = 0; i < lotteryConfig.numOfWinners; i++) {
            uint256 winningIndex = randomResult % lotteryConfig.playersLimit;
            address userAddress = lotteryPlayers[winningIndex];
            while (winnerAddresses[userAddress]) {
                randomResult = randomResult * getRandomNumberBlockchain();
                winningIndex = randomResult % lotteryConfig.playersLimit;
                userAddress = lotteryPlayers[winningIndex];
            }
            winnerAddresses[userAddress] = true;
            winners.push(userAddress);
            lotteryToken.transfer(userAddress, winnersPool);
        }
        //transfer to Admin
        lotteryToken.transfer(adminAddress, adminFees);
        lotteryStatus = LotteryStatus.CLOSED;
    }

    function getRandomNumberBlockchain() internal view returns (uint256) {
        return
            uint256(
                keccak256(abi.encodePacked(block.timestamp, block.difficulty))
            );
    }

    function resetLottery() public {
        require(
            msg.sender == adminAddress,
            "Resetting the Lottery requires Admin Access"
        );
        require(
            lotteryStatus == LotteryStatus.CLOSED,
            "Starting the Lottery requires Admin Access"
        );
        delete lotteryConfig;
        delete adminAddress;
        delete randomResult;
        delete lotteryPlayers;
        delete lotteryStatus;
        delete keyHashVRF;
        delete feeVRF;
        delete totalLotteryPool;
        for (uint256 i = 0; i < winners.length; i++) {
            winnerAddresses[winners[i]] = false;
        }
        delete winners;
    }

    //add logic to reset contract variblaes values
    // save historic data of Lottery
    //error handling
    //random number integration and making sure that the contract always has LINK tokens
}
