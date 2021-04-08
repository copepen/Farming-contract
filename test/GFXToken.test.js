const { assert } = require('chai');
const GFXToken = artifacts.require('GFXToken');

contract('GFXToken', ([governance, minter, alice, bob, carol, dev]) => {
    beforeEach(async () => {
        this.gfx = await GFXToken.new({ from: governance });
        await this.gfx.addMinter(minter, {from: governance});
    });


    it('balanceOf() function test', async () => {
        assert.equal((await this.gfx.balanceOf(alice)).toString(), '0');

        await this.gfx.mint(alice, 1000, { from: minter });
        assert.equal((await this.gfx.balanceOf(alice)).toString(), '1000');
    })

    it('mint() function test', async () => {
        await this.gfx.mint(alice, 1000, { from: minter });
        await this.gfx.mint(bob, 500, { from: minter });

        assert.equal((await this.gfx.balanceOf(alice)).toString(), '1000');
        assert.equal((await this.gfx.balanceOf(bob)).toString(), '500');
        assert.equal((await this.gfx.totalSupply()).toString(), '1500');
    })

    it('burn() function test', async () => {
        await this.gfx.mint(alice, 1000, { from: minter });
        await this.gfx.mint(bob, 500, { from: minter });
        assert.equal((await this.gfx.totalSupply()).toString(), '1500');

        await this.gfx.burn(200, { from: alice });
        assert.equal((await this.gfx.balanceOf(alice)).toString(), '800');
        assert.equal((await this.gfx.totalSupply()).toString(), '1300');
    })

    it('addMinter() function test', async () => {
        assert.equal((await this.gfx.minters(alice)), false);

        await this.gfx.addMinter(alice, {from: governance})
        assert.equal((await this.gfx.minters(alice)), true);
    })

    it('removeMinter() function test', async () => {
        assert.equal((await this.gfx.minters(alice)), false);

        await this.gfx.addMinter(alice, {from: governance})
        assert.equal((await this.gfx.minters(alice)), true);

        await this.gfx.removeMinter(alice, {from: governance})
        assert.equal((await this.gfx.minters(alice)), false);
    })
});
