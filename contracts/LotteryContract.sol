pragma solidity ^0.6.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

contract LotteryContract is VRFConsumerBase {
    struct RulesConfig {
        uint256 numOfWinners;
        uint256 playerLimit;
        uint256 registrationAmount;
        uint256 adminFeePercentage;
        address tokenAddress;
    }

    address[] lotteryPlayers;
    address adminAddress;
    enum LotteryStatus {NOTSTARTED, INPROGRESS, CLOSED}
    mapping(address => bool) winnerAddresses;
    address[] winners;
    uint256 totalLotteryPool;

    IERC20 lotteryToken;
    LotteryStatus lotteryStatus;
    RulesConfig rulesConfig;

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

    function getRandomNumber(uint256 userProvidedSeed)
        public
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
        uint256 playerLimit,
        uint256 registrationAmount,
        uint256 adminFeePercentage,
        address tokenAddress
    ) public {
        require(
            msg.sender == adminAddress,
            "Starting the Lottery requires Admin Access"
        );
        require(
            lotteryStatus == LotteryStatus.NOTSTARTED,
            "Starting the Lottery requires Admin Access"
        );
        rulesConfig = RulesConfig(
            numOfWinners,
            playerLimit,
            registrationAmount,
            adminFeePercentage,
            tokenAddress
        );
        lotteryStatus = LotteryStatus.INPROGRESS;
        lotteryToken = IERC20(tokenAddress);
    }

    function enterLottery() public returns (bool) {
        require(
            lotteryPlayers.length < rulesConfig.playerLimit,
            "Max Participation for the Lottery Reached"
        );
        //add condition if address has already entered
        require(
            lotteryStatus == LotteryStatus.INPROGRESS,
            "The Lottery is Closed"
        );
        require(
            lotteryToken.allowance(msg.sender, address(this)) >=
                rulesConfig.registrationAmount,
            "Contract is not allowed to spend this"
        );
        lotteryPlayers.push(msg.sender);
        lotteryToken.transferFrom(
            msg.sender,
            address(this),
            rulesConfig.registrationAmount
        );
        //if condition here to close lottery after max participation
        totalLotteryPool += rulesConfig.registrationAmount;
        return true;
    }

    function settleLottery() internal {
        require(msg.sender == adminAddress, "Requires Admin Access");
        uint256 adminFees = (totalLotteryPool *
            rulesConfig.adminFeePercentage) / 100;
        uint256 winnersPool = (totalLotteryPool - adminFees) /
            rulesConfig.numOfWinners;
        //temporary logic till we put the random number logic
        uint256 winningIndex = 0;
        winners.push(lotteryPlayers[winningIndex]);
        for (uint256 i = 0; i < rulesConfig.numOfWinners; i++) {
            address winnerAddress = winners[i];
            lotteryToken.transferFrom(
                address(this),
                winnerAddress,
                winnersPool
            );
        }
        //transfer to Admin
        lotteryToken.transferFrom(address(this), adminAddress, adminFees);
        lotteryStatus = LotteryStatus.CLOSED;
    }

    //add logic to reset contract variblaes values
    // save historic data of Lottery
    //error handling
    //random number integration and making sure that the contract always has LINK tokens
}
