pragma solidity ^0.6.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LotteryContract {
    
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

    constructor() public
    {
        adminAddress = msg.sender;
        lotteryStatus = LotteryStatus.NOTSTARTED;
        totalLotteryPool = 0;
    }

    function setLotteryRules(
        uint256 numOfWinners,
        uint256 playerLimit,
        uint256 registrationAmount,
        uint256 adminFeePercentage,
        address tokenAddress
    ) public {
        require(msg.sender == adminAddress, "Starting the Lottery requires Admin Access");
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
        require(lotteryStatus == LotteryStatus.INPROGRESS, "The Lottery is Closed");
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
        uint256 adminFees = (totalLotteryPool * rulesConfig.adminFeePercentage)/100;
        uint256 winnersPool = (totalLotteryPool - adminFees) /  rulesConfig.numOfWinners;
        //temporary logic till we put the random number logic
        uint winningIndex = 0;
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
