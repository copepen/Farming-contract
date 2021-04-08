const { expectRevert, time } = require('@openzeppelin/test-helpers');
const GFXToken = artifacts.require('GFXToken');
const GamyFiFarm = artifacts.require('GamyFiFarm');
const LPToken = artifacts.require('LPToken');

contract('GamyFiFarm',([governance, minter, alice, bob, carol, marketAddr]) => {
    beforeEach(async () => {
        this.gfx = await GFXToken.new({ from: minter });
        this.rewardPerBlock = '500';
        this.maxRewardBlockNumber = '8934827';
        this.marketAddr = marketAddr;

        this.gfx = await GFXToken.new({ from: governance });
        this.lp1 = await LPToken.new('GFX-ETH', 'GFX-ETH', '1000000', { from: governance });
        this.lp2 = await LPToken.new('GFX-USDT', 'GFX-USDT', '1000000', { from: governance }); 
        // this.lp3 = await LPToken.new('GFX-USDC', 'GFX-USDC', '1000000', { from: governance });        
        this.GamyFiFarm = await GamyFiFarm.new(this.gfx.address, this.marketAddr, this.rewardPerBlock, this.maxRewardBlockNumber, { from: governance });
        
        // set Farm contract as a minter
        await this.gfx.addMinter(this.GamyFiFarm.address, {from: governance});
      
        // initial supply
        await this.lp1.transfer(alice, '2000', { from: governance });
        await this.lp2.transfer(alice, '2000', { from: governance });
        await this.lp1.transfer(bob, '2000', { from: governance });
        await this.lp2.transfer(bob, '2000', { from: governance });
    });

    it('poolLength(): pool length test', async () => {
      assert.equal((await this.GamyFiFarm.poolLength()).toString(), "0");
    })

    it('add(): add a new pool test', async () => {
      assert.equal((await this.GamyFiFarm.poolLength()).toString(), "0");
      await this.GamyFiFarm.add('10', this.lp2.address, true, { from: governance });
      assert.equal((await this.GamyFiFarm.poolLength()).toString(), "1");
    })

    it('set(): update pool test', async () => {
      await this.GamyFiFarm.add('10', this.lp2.address, true, { from: governance });
      await this.GamyFiFarm.set(0, '20', true, { from: governance });
      const firstPoolInfo = await this.GamyFiFarm.poolInfo(0);
      assert.equal(firstPoolInfo[1].toString(), "20");
    })

    it('updateMaxRewardBlockNumber(): update maxRewardBlockNumber test', async () => {
      await this.GamyFiFarm.updateMaxRewardBlockNumber('9000000', { from: governance });
      assert.equal((await this.GamyFiFarm.maxRewardBlockNumber()).toString(), "9000000");
    })

    it('updateMultiplier(): update multiplier test', async () => {
      await this.GamyFiFarm.updateMultiplier('2', {from: governance});
      assert.equal((await this.GamyFiFarm.BONUS_MULTIPLIER()).toString(), "2");
    })

    it('updateMarketAddr(): update marketAddress test', async () => {
      assert.equal((await this.GamyFiFarm.marketAddr()).valueOf(), marketAddr);
      await expectRevert(this.GamyFiFarm.updateMarketAddr(bob, { from: bob }), 'dev: wut?');

      await this.GamyFiFarm.updateMarketAddr(bob, { from: marketAddr });
      assert.equal((await this.GamyFiFarm.marketAddr()).valueOf(), bob);

      await this.GamyFiFarm.updateMarketAddr(alice, { from: bob });
      assert.equal((await this.GamyFiFarm.marketAddr()).valueOf(), alice);
    })

    it('updateRewardPerBlock(): update rewardPerBlock test', async () => {
      await this.GamyFiFarm.updateRewardPerBlock('6000000000000000000', { from: governance });
      assert.equal((await this.GamyFiFarm.rewardPerBlock()).toString(), "6000000000000000000");
    })


    it('deposit/withdraw', async () => {
      await this.GamyFiFarm.add('1000', this.lp1.address, true, { from: governance });
      await this.GamyFiFarm.add('1000', this.lp2.address, true, { from: governance });

      await this.lp1.approve(this.GamyFiFarm.address, '100', { from: alice });
      await this.GamyFiFarm.deposit(0, '20', { from: alice });
      await this.GamyFiFarm.deposit(0, '0', { from: alice });
      await this.GamyFiFarm.deposit(0, '40', { from: alice });
      await this.GamyFiFarm.deposit(0, '0', { from: alice });
      assert.equal((await this.lp1.balanceOf(alice)).toString(), '1940');

      await this.GamyFiFarm.withdraw(0, '10', { from: alice });
      assert.equal((await this.lp1.balanceOf(alice)).toString(), '1950');
      assert.equal((await this.gfx.balanceOf(alice)).toString(), '999');
      assert.equal((await this.gfx.balanceOf(marketAddr)).toString(), '18');

      await this.lp1.approve(this.GamyFiFarm.address, '100', { from: bob });
      assert.equal((await this.lp1.balanceOf(bob)).toString(), '2000');
      await this.GamyFiFarm.deposit(0, '50', { from: bob });
      assert.equal((await this.lp1.balanceOf(bob)).toString(), '1950');
      await this.GamyFiFarm.deposit(0, '0', { from: bob });
      assert.equal((await this.gfx.balanceOf(bob)).toString(), '125');
      await this.GamyFiFarm.emergencyWithdraw(0, { from: bob });
      assert.equal((await this.lp1.balanceOf(bob)).toString(), '2000');
    })
});
