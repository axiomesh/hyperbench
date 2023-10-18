pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AxiomOne is ERC20 {
    constructor(string memory _name, string memory _symbol, address _mintToAddr) ERC20(_name, _symbol) {
        _mint(_mintToAddr, 1000000000000000000000);
    }

    // 铸造代币
    function mint(address recipient, uint256 amount) public {
        _mint(recipient, amount);
    }

    // 销毁代币
    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }
}