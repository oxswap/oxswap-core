// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./libraries/SafeMath.sol";
import "./libraries/SafeERC20.sol";
import "./interfaces/IERC20Burnable.sol";
import "./uniswapv2/interfaces/IUniswapV2ERC20.sol";
import "./uniswapv2/interfaces/IUniswapV2Pair.sol";
import "./uniswapv2/interfaces/IUniswapV2Factory.sol";

import "./Ownable.sol";

contract OxSwapMaker is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IUniswapV2Factory public immutable factory;
    address private immutable oxst;
    address private immutable weth;

    mapping(address => address) internal _bridges;

    event LogBridgeSet(address indexed token, address indexed bridge);
    event LogConvert(address indexed server, address indexed token0, address indexed token1, uint256 amount0, uint256 amount1, uint256 amountOXST);

    constructor (address _factory, address _oxst, address _weth) public {
       factory = IUniswapV2Factory(_factory);
       oxst = _oxst;
       weth = _weth;
    }

    function bridgeFor(address token) public view returns (address bridge) {
        bridge = _bridges[token];
        if (bridge == address(0)) {
            bridge = weth;
        }
    }

    function setBridge(address token, address bridge) external onlyOwner {
        require(token != oxst && token != weth && token != bridge, "OxSwap Maker: Invalid bridge");
        _bridges[token] = bridge;
        emit LogBridgeSet(token, bridge);
    }

    modifier onlyEOA() {
        require(msg.sender == tx.origin, "OxSwap Maker: must use EOA");
        _;
    }

    function convert(address token0, address token1) external onlyEOA() {
        _convert(token0, token1);
    }

    function convertMultiple(address[] calldata token0, address[] calldata token1) external onlyEOA() {
        uint256 len = token0.length;
        for(uint256 i=0; i < len; i++) {
            _convert(token0[i], token1[i]);
        }
    }

    function _convert(address token0, address token1) internal {
        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(token0, token1));
        require(address(pair) != address(0), "OxSwap Maker: Invalid pair");
        IERC20(address(pair)).safeTransfer(address(pair), pair.balanceOf(address(this)));
        (uint256 amount0, uint256 amount1) = pair.burn(address(this));
        if (token0 != pair.token0()) {
            (amount0, amount1) = (amount1, amount0);
        }
        emit LogConvert(msg.sender, token0, token1, amount0, amount1, _convertStep(token0, token1, amount0, amount1));
    }

    function _convertStep(address token0, address token1, uint256 amount0, uint256 amount1) internal returns(uint256 oxstOut) {
        if (token0 == token1) {
            uint256 amount = amount0.add(amount1);
            if (token0 == oxst) {
                IERC20BURNABLE(oxst).burn(address(this), amount);
                oxstOut = amount;
            } else if (token0 == weth) {
                oxstOut = _toOXST(weth, amount);
            } else {
                address bridge = bridgeFor(token0);
                amount = _swap(token0, bridge, amount, address(this));
                oxstOut = _convertStep(bridge, bridge, amount, 0);
            }
        } else if (token0 == oxst) {
            IERC20BURNABLE(oxst).burn(address(this), amount0); 
            oxstOut = _toOXST(token1, amount1).add(amount0);
        } else if (token1 == oxst) { 
            IERC20BURNABLE(oxst).burn(address(this), amount1); 
            oxstOut = _toOXST(token0, amount0).add(amount1); 
        } else if (token0 == weth) { 
            oxstOut = _toOXST(weth, _swap(token1, weth, amount1, address(this)).add(amount0));
        } else if (token1 == weth) { 
            oxstOut = _toOXST(weth, _swap(token0, weth, amount0, address(this)).add(amount1));
        } else { 
            address bridge0 = bridgeFor(token0);
            address bridge1 = bridgeFor(token1);
            if (bridge0 == token1) { 
                oxstOut = _convertStep(bridge0, token1,
                    _swap(token0, bridge0, amount0, address(this)),
                    amount1
                );
            } else if (bridge1 == token0) { 
                oxstOut = _convertStep(token0, bridge1,
                    amount0,
                    _swap(token1, bridge1, amount1, address(this))
                );
            } else {
                oxstOut = _convertStep(bridge0, bridge1, 
                    _swap(token0, bridge0, amount0, address(this)),
                    _swap(token1, bridge1, amount1, address(this))
                );
            }
        }
    }

    function _swap(address fromToken, address toToken, uint256 amountIn, address to) internal returns (uint256 amountOut) {
        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(fromToken, toToken));
        require(address(pair) != address(0), "OxSwap Maker: Cannot convert");
        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
        uint256 amountInWithFee = amountIn.mul(997);
        if (fromToken == pair.token0()) {
            amountOut = amountIn.mul(997).mul(reserve1) / reserve0.mul(1000).add(amountInWithFee);
            IERC20(fromToken).safeTransfer(address(pair), amountIn);
            pair.swap(0, amountOut, to, new bytes(0));
        } else {
            amountOut = amountIn.mul(997).mul(reserve0) / reserve1.mul(1000).add(amountInWithFee);
            IERC20(fromToken).safeTransfer(address(pair), amountIn);
            pair.swap(amountOut, 0, to, new bytes(0));
        }
    }

    function _toOXST(address token, uint256 amountIn) internal returns(uint256 amountOut) {
        amountOut = _swap(token, oxst, amountIn, address(this));
        IERC20BURNABLE(oxst).burn(address(this), amountOut);
    }
}
