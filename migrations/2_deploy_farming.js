const GamyFiFarm = artifacts.require("GamyFiFarm");
const { settings } = require("../config");

module.exports = async function (deployer, network) {
  const setting = settings[network];

  deployer.deploy(
    GamyFiFarm,
    setting.gfx,
    setting.marketAddr,
    setting.rewardPerBlock,
    setting.maxRewardBlockNumber
  );
};
