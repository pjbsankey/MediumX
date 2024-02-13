// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//Elastic Supply Token Contract based on Jens O'Parsson's equation prices = token supply x token velocity / supply of real values. Aim of contract is to keep prices index stable

contract Stablecoin is ERC20 {
    address public owner;
    AggregatorV3Interface public m2vOracle;
    AggregatorV3Interface public gdpOracle;

    uint256 public targetPrice;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _m2vOracleAddress,
        address _gdpOracleAddress,
        uint256 _initialSupply,
        uint256 _targetPrice
    ) ERC20(_name, _symbol) {
        owner = msg.sender;
        m2vOracle = AggregatorV3Interface(_m2vOracleAddress);
        gdpOracle = AggregatorV3Interface(_gdpOracleAddress);
        targetPrice = _targetPrice;
        _mint(msg.sender, _initialSupply);
    }

    function getCurrentPrice() public view returns (uint256) {
        uint256 m2v = getCurrentM2V();
        uint256 gdp = getCurrentGDP();

        // Prices = money quantity * money velocity / real gdp
        return (totalSupply() * m2v) / gdp;
    }

    function getCurrentM2V() public view returns (uint256) {
        (, int256 m2v, , , ) = m2vOracle.latestRoundData();
        require(m2v > 0, "Invalid M2V data");
        return uint256(m2v);
    }

    function getCurrentGDP() public view returns (uint256) {
        (, int256 gdp, , , ) = gdpOracle.latestRoundData();
        require(gdp > 0, "Invalid GDP data");
        return uint256(gdp);
    }

  function adjustMoneySupply() external onlyOwner {
    uint256 currentPrice = getCurrentPrice();

    // Define a tolerance level of 0.1% (0.001)
    uint256 tolerance = targetPrice / 1000;

    if (currentPrice > targetPrice + tolerance) {
        // Contract money supply contraction logic
        // Calculate the ratio of target price to current price
        uint256 contractionRatio = (targetPrice * 1e18) / currentPrice; // Multiply by 1e18 for precision

        // Avoid excessive burning if the ratio is close to 1
        if (contractionRatio < 1e18) {
            return;
        }

        // Calculate the amount to burn based on the contraction ratio
        uint256 burnAmount = totalSupply() * (1e18 - contractionRatio) / 1e18;

        // Burn tokens to adjust the money supply
        _burn(msg.sender, burnAmount);
    } else if (currentPrice < targetPrice - tolerance) {
        // Contract money supply expansion logic
        // Calculate the ratio of current price to target price
        uint256 expansionRatio = (currentPrice * 1e18) / targetPrice; // Multiply by 1e18 for precision

        // Avoid excessive minting if the ratio is close to 1
        if (expansionRatio < 1e18) {
            return;
        }

        // Calculate the amount to mint based on the expansion ratio
        uint256 mintAmount = totalSupply() * (expansionRatio - 1e18) / 1e18;

        // Mint new tokens to adjust the money supply
        _mint(msg.sender, mintAmount);
    }
}
}
