pragma solidity 0.6.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract GFXToken is ERC20 {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    uint256 public _maxSupply = 0;
    uint256 private _totalSupply;

    address public governance;
    mapping(address => bool) public minters;

    constructor() public ERC20("GamyFi Token", "GFX") {
        governance = msg.sender;
        _maxSupply = 10000000 * (10**18);
    }

    function mint(address account, uint256 amount) public {
        require(minters[msg.sender], "!minter");
        uint256 newMintSupply = _totalSupply.add(amount);
        require(newMintSupply <= _maxSupply, "supply is max!");
        _totalSupply = _totalSupply.add(amount);
        _mint(account, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function setGovernance(address _governance) public {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    function addMinter(address _minter) public {
        require(msg.sender == governance, "!governance");
        minters[_minter] = true;
    }

    function removeMinter(address _minter) public {
        require(msg.sender == governance, "!governance");
        minters[_minter] = false;
    }
}
