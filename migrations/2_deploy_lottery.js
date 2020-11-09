const LotteryContract = artifacts.require("LotteryContract");

module.exports = function (deployer) {
  deployer.deploy(LotteryContract);
};
