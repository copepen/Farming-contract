const settings = {
  live: {
    gfx: "0x31739e3027df1d2cd6559e9d292daa2446ef5e54",
    marketAddr: "0xA557572933cA2b5f644A0fAa6383D78Ec3D4E153",
    rewardPerBlock: "5000000000000000000", // 5 per block,
    maxRewardBlockNumber: "22000000", // 5 years from now
  },
  rinkeby: {
    gfx: "0x31739e3027df1d2cd6559e9d292daa2446ef5e54",
    marketAddr: "0xA557572933cA2b5f644A0fAa6383D78Ec3D4E153",
    rewardPerBlock: "5000000000000000000", // 5 per block,
    maxRewardBlockNumber: "8934827",
  },
  development: {
    gfx: "0x31739e3027df1d2cd6559e9d292daa2446ef5e54",
    marketAddr: "0xA557572933cA2b5f644A0fAa6383D78Ec3D4E153",
    rewardPerBlock: "5000000000000000000", // 5 per block,
    maxRewardBlockNumber: "8934827",
  },
};

module.exports = { settings };
