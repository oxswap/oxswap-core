// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./uniswapv2/interfaces/IUniswapV2Pair.sol";
import "./uniswapv2/interfaces/IUniswapV2Factory.sol";
import "./uniswapv2/interfaces/IWETH.sol";

contract OxSwapDelegate is Ownable{
	using SafeMath for uint256;
	mapping(address => delegatorData) public delegatorStats;
	address private multiTransfer;
	address public bbusd = 0x0aB43550A6915F9f67d0c454C2E90385E6497EaA;
	address public oxst = 0x12F0e8B217F095B33be6b73b4B61e5487E46F5C9;
	address public weth = 0xcF664087a5bB0237a0BAd6742852ec6c8d69A27a;

	IUniswapV2Factory public immutable factory = IUniswapV2Factory(0xC342d6CCd44A198A4f2B19645FaA687eebca600F);

	struct delegatorData {
	   address delegatorAddr;
	   uint256 oneStaked;
	   uint256 oxratio;
	   uint256 earnedOne;
	   uint256 earnedOxst;
	   uint256 earnedUsd;
	}

	modifier onlyMultiTransfer{
		require(msg.sender == multiTransfer, "Non.");
		 _;
	}

	function setMultiTransfer(address _contract) public onlyOwner{
		multiTransfer = _contract;
	}

	function setRatioPercentageOxSwap(uint256 _ratio) public {
		require(_ratio >= 30, "Minimum must be 30% OXST...");
		require(_ratio <= 100, "Only up to 100%. Love, dev.");
		delegatorData storage del = delegatorStats[tx.origin];
		del.oxratio = _ratio;
	}
	function getRatio(address _user) public view returns(uint256){
		delegatorData storage del = delegatorStats[_user];
		if(del.oxratio == 0) {
			return uint256(100);
		} else {
			return del.oxratio;
		}	
	}


	function logUser(address userAddr,uint256 stakedAmount,uint256 oxstAmount,uint256 oneAmount) public onlyMultiTransfer {
		delegatorData storage del = delegatorStats[userAddr];
		uint256 usdOne;
		if(oneAmount != 0){
			usdOne = valueUSD(weth, bbusd, oneAmount);
		}
		uint256 usdOxst = valueUSD(oxst, bbusd, oxstAmount);
		del.earnedUsd = del.earnedUsd + usdOxst + usdOne;
		del.earnedOne += oneAmount;
		del.earnedOxst += oxstAmount;
		if(del.delegatorAddr == address(0)){
			del.delegatorAddr = userAddr;
		}
		if(stakedAmount != del.oneStaked){
			del.oneStaked = stakedAmount;
		}
	}
	function valueUSD(address fromToken,address toToken,uint256 amountIn)public returns(uint256){
		uint256 amountOut;
	        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(fromToken, toToken));
        	(uint256 reserve0, uint256 reserve1,) = pair.getReserves();
        	uint256 amountInWithFee = amountIn.mul(997);
        	if (fromToken == pair.token0()) {
         		amountOut = amountIn.mul(997).mul(reserve1) / reserve0.mul(1000).add(amountInWithFee);
         	} else {
         		amountOut = amountIn.mul(997).mul(reserve0) / reserve1.mul(1000).add(amountInWithFee);
         	}
      		return amountOut;
	}
}