// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Ownable.sol";

contract OxSwapToken is ERC20("OxSwap Token", "OXST"), Ownable {
    uint256 public burnCount;

    event Mint(address indexed user, uint amount);

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
        emit Mint(_to, _amount);
    }

    function burn(address _account, uint256 _amount) public {
        require(_account == msg.sender, "You can't burn tokens you dont own.");
        _burn(_account, _amount);
        burnCount = burnCount + _amount;
    }
}