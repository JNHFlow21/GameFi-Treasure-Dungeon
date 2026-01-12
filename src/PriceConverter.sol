// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title PriceConverter
 * @dev ETH/USD价格转换库，使用Chainlink价格预言机
 * @author GameFi Treasure Dungeon
 */
library PriceConverter {
    error PriceConverter__InvalidPrice();
    error PriceConverter__StalePrice();

    /**
     * @dev 获取ETH/USD最新价格
     * @param priceFeed 价格预言机地址
     * @return 价格（精度与 Aggregator decimals 一致）
     */
    function getPrice(address priceFeed) internal view returns (uint256) {
        AggregatorV3Interface ethUsdPriceFeed = AggregatorV3Interface(priceFeed);
        (uint80 roundId, int256 price,, uint256 updatedAt, uint80 answeredInRound) =
            ethUsdPriceFeed.latestRoundData();
        if (price <= 0) {
            revert PriceConverter__InvalidPrice();
        }
        if (updatedAt == 0 || answeredInRound < roundId) {
            revert PriceConverter__StalePrice();
        }
        return uint256(price);
    }

    /**
     * @dev 获取ETH价值的USD金额
     * @param ethAmount ETH数量，18位精度
     * @param priceFeed 价格预言机地址
     * @return 等值USD金额，18位精度
     */
    function getUsdValue(uint256 ethAmount, address priceFeed) internal view returns (uint256) {
        uint256 ethPrice = getPrice(priceFeed);
        uint256 ethPriceInWei = _scalePrice(priceFeed, ethPrice);
        uint256 ethToUsd = (ethPriceInWei * ethAmount) / 1e18;
        return ethToUsd;
    }

    /**
     * @dev 根据USD金额计算等值ETH数量
     * @param usdAmount USD金额，18位精度
     * @param priceFeed 价格预言机地址
     * @return 等值ETH数量，18位精度
     */
    function getEthAmount(uint256 usdAmount, address priceFeed) internal view returns (uint256) {
        uint256 ethPrice = getPrice(priceFeed);
        uint256 ethPriceInWei = _scalePrice(priceFeed, ethPrice);
        uint256 usdToEth = (usdAmount * 1e18) / ethPriceInWei;
        return usdToEth;
    }

    function _scalePrice(address priceFeed, uint256 price) private view returns (uint256) {
        AggregatorV3Interface ethUsdPriceFeed = AggregatorV3Interface(priceFeed);
        uint256 decimals = uint256(ethUsdPriceFeed.decimals());
        if (decimals == 18) {
            return price;
        }
        if (decimals < 18) {
            return price * (10 ** (18 - decimals));
        }
        return price / (10 ** (decimals - 18));
    }
}
