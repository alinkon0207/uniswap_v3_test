// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// WETH
interface IWETH9 {
    function withdraw(uint wad) external;
}

// Uniswap V3
library TransferHelper {
    function safeApprove(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SA"
        );
    }
}

interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}

interface ISwapRouter is IUniswapV3SwapCallback {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(
        ExactInputParams calldata params
    ) external payable returns (uint256 amountOut);
}

contract TestingToken is ERC20, Ownable {
   
    address private constant WETH_ADDRESS = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

    ISwapRouter public constant uni_router_v3 =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564); //Uniswap v3 Router on Goerli
    IWETH9 public constant weth =
        IWETH9(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6); //weth  on Goerli

    constructor(address initialOwner, uint256 initialSupply) ERC20("TestingToken", "UTK") Ownable(initialOwner) {
        _mint(msg.sender, initialSupply);
    }

    function swapThisToken2ETH( 
       uint256 _amount
    ) external onlyOwner {
        // Implement token swapping logic using UniswapV3Pool swap function
        swapTokensOnUniswapV3(address(this), WETH_ADDRESS, _amount, 3000);
    }

    function swapWETH2ThisToken(
       uint256 _amount
    ) external onlyOwner {
        // Implement WETH swapping logic using UniswapV3Pool swap function
        swapTokensOnUniswapV3(WETH_ADDRESS, address(this), _amount, 3000);
    }
    
    function swapTokensOnUniswapV3(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint24 _fee
    ) public payable {
        TransferHelper.safeApprove(_tokenIn, address(uni_router_v3), _amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: _tokenOut,
                fee: _fee,
                recipient: address(this),
                deadline: block.timestamp + 300,
                amountIn: _amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        uni_router_v3.exactInputSingle(params);
    }

    receive() external payable {}

    fallback() external payable {}
}
