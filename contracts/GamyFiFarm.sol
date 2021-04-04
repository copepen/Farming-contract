pragma solidity 0.6.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./GFXToken.sol";

contract GamyFiFarm is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of token or LP contract
        uint256 allocPoint; // How many allocation points assigned to this pool. gfx to distribute per block.
        uint256 lastRewardBlock; // Last block number that gfx distribution occurs.
        uint256 accGFXPerShare; // Accumulated gfx per share, times 1e18. See below.
    }

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when gfx mining starts ->

    // max reward block
    uint256 public maxRewardBlockNumber;

    // rewad per block in wei
    uint256 public rewardPerBlock;

    // reward point of market
    uint256 public marketRewardPoint = 1;

    // Bonus muliplier for early gfx makers.
    uint256 public BONUS_MULTIPLIER = 1;

    // Accumulated gfx per share, times 1e18.
    uint256 public accGFXPerShareMultiple = 1e18;

    // The reward token!
    GFXToken public gfx;

    // Dev address.
    address public marketAddr;

    // Info on each pool added
    PoolInfo[] public poolInfo;
    // Info of each user that stakes tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event ClaimReward(address indexed user, uint256 indexed pid);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        GFXToken _gfx,
        address _marketAddr,
        uint256 _rewardPerBlock,
        uint256 _maxRewardBlockNumber
    ) public {
        gfx = _gfx;
        rewardPerBlock = _rewardPerBlock;
        maxRewardBlockNumber = _maxRewardBlockNumber;
        marketAddr = _marketAddr;
    }

    // Get total reward in selected pool
    function getTotalRewardByPoolId(uint256 _pid, address _address)
        public
        view
        returns (uint256)
    {
        require(
            poolInfo.length > 0,
            "There is no pools yet"
        );
        UserInfo storage user = userInfo[_pid][_address];

        uint256 poolRewardPerShare = getPoolRewardPerShare(_pid);
        uint256 totalReward =
            user.amount.mul(poolRewardPerShare).div(accGFXPerShareMultiple).sub(
                user.rewardDebt
            );

        return totalReward;
    }

    // Get total reward in all pools
    function getTotalReward(address _address) public view returns (uint256) {
        require(
            poolInfo.length > 0,
            "There is no pools yet"
        );
        uint256 totalReward = 0;
        uint256 length = poolInfo.length;

        for (uint256 pid = 0; pid < length; ++pid) {
            UserInfo storage user = userInfo[pid][_address];

            uint256 poolRewardPerShare = getPoolRewardPerShare(pid);

            totalReward = totalReward.add(
                user
                    .amount
                    .mul(poolRewardPerShare)
                    .div(accGFXPerShareMultiple)
                    .sub(user.rewardDebt)
            );
        }

        return totalReward;
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    // Pool Length
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Update maxRewardBlockNumber
    function updateMaxRewardBlockNumber(uint256 _newMaxRewardBlockNumber)
        public
        onlyOwner
    {
        maxRewardBlockNumber = _newMaxRewardBlockNumber;
    }

    // Update marketAddr
    function updateMarketAddr(address _marketAddr) public {
        require(msg.sender == marketAddr, "dev: wut?");
        marketAddr = _marketAddr;
    }

    // Update rewardPerBlock
    function updateRewardPerBlock(uint256 _rewardPerBlock) public onlyOwner {
        rewardPerBlock = _rewardPerBlock;
    }

    // Redeem all reward Tokens
    function redeemAllRewards(address _to) public onlyOwner {
        uint256 gfxBal = gfx.balanceOf(address(this));
        gfx.transfer(_to, gfxBal);
    }

    // Add a new token or LP to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do!
    function add(
        uint256 _allocPoint,
        IERC20 _token, // lp token address
        bool _withUpdate
    ) public onlyOwner {
        require(_allocPoint > 0, "AllocPoint can't be null");

        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _token,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accGFXPerShare: 0
            })
        );
    }

    // Update the given pool's gfx allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        require(
            pool.lastRewardBlock <= maxRewardBlockNumber,
            "Max pool cap already reached, you cant join this pool"
        );
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 gfxReward =
            multiplier.mul(rewardPerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );
        uint256 marketGfxReward = gfxReward.mul(marketRewardPoint).div(100);
        gfx.mint(marketAddr, marketGfxReward);

        pool.accGFXPerShare = getPoolRewardPerShare(_pid);
        pool.lastRewardBlock = block.number;
    }

    // Safe gfx transfer function, just in case if rounding error causes pool to not have enough $gfx
    function safeGFXMint(address _to, uint256 _amount) internal {
        gfx.mint(_to, _amount);
    }

    // Deposit tokens to GamyFiFarm Test for gfx allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        require(
            poolInfo.length > 0,
            "There is no pools yet"
        );
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending =
                user
                    .amount
                    .mul(pool.accGFXPerShare)
                    .div(accGFXPerShareMultiple)
                    .sub(user.rewardDebt);
            if (pending > 0) {
                safeGFXMint(msg.sender, pending);
            }
        }

        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.amount = user.amount.add(_amount);

        user.rewardDebt = user.amount.mul(pool.accGFXPerShare).div(
            accGFXPerShareMultiple
        );
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw tokens from GamyFiFarm Test
    function withdraw(uint256 _pid, uint256 _amount) public {
        require(
            poolInfo.length > 0,
            "There is no pools yet"
        );
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);

        uint256 pending =
            user
                .amount
                .mul(pool.accGFXPerShare)
                .div(accGFXPerShareMultiple)
                .sub(user.rewardDebt);

        if (pending > 0) {
            safeGFXMint(msg.sender, pending);
        }

        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }

        user.rewardDebt = user.amount.mul(pool.accGFXPerShare).div(
            accGFXPerShareMultiple
        );
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw tokens from GamyFiFarm Test
    function claimReward(uint256 _pid) public {
        require(
            poolInfo.length > 0,
            "There is no pools yet"
        );
        UserInfo storage user = userInfo[_pid][msg.sender];
        
        updatePool(_pid);

        uint256 poolRewardPerShare = getPoolRewardPerShare(_pid);

        uint256 pending =
            user.amount.mul(poolRewardPerShare).div(accGFXPerShareMultiple).sub(
                user.rewardDebt
            );

        if (pending > 0) {
            safeGFXMint(msg.sender, pending);
        }

        user.rewardDebt = user.amount.mul(poolRewardPerShare).div(
            accGFXPerShareMultiple
        );
        emit ClaimReward(msg.sender, _pid);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe gfx transfer function, just in case if rounding error causes pool to not have enough $gfx
    function getPoolRewardPerShare(uint256 _pid)
        internal
        view
        returns (uint256)
    {
        require(
            poolInfo.length > 0,
            "There is no pools yet"
        );
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number < pool.lastRewardBlock) {
            return 0;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            return 0;
        }
        if (pool.lastRewardBlock > maxRewardBlockNumber) {
            return 0;
        }

        uint256 currentRewardBlock = block.number;
        if (block.number >= maxRewardBlockNumber) {
            currentRewardBlock = maxRewardBlockNumber;
        }

        uint256 multiplier =
            getMultiplier(pool.lastRewardBlock, currentRewardBlock);

        uint256 totalReward = multiplier.mul(rewardPerBlock);

        uint256 poolReward =
            totalReward.mul(pool.allocPoint).div(totalAllocPoint);

        return
            pool.accGFXPerShare.add(
                poolReward.mul(accGFXPerShareMultiple).div(lpSupply)
            );
    }
}
