// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import "@uniswap/v3-periphery/contracts/libraries/Path.sol";
import "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract TestingToken is Initializable, ERC20Upgradeable, IUniswapV3SwapCallback {

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

    struct SwapCallbackData {
        bytes path;
        address payer;
    }


    using Path for bytes;
    using Strings for uint256;

    
    address private constant WETH9 = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6; // WETH9 on Goerli
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    /// Used as the placeholder value for amountInCached, because the computed amount in for an exact output swap
    /// can never actually be this value
    uint256 private constant DEFAULT_AMOUNT_IN_CACHED = type(uint256).max;

    IWETH9 private constant weth = IWETH9(WETH9); // weth
    ISwapRouter private constant uni_router_v3 = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564); // UniswapV3Router
    
    
    address private factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;   // UniswapV3Factory
    /// Transient storage variable used for returning the computed amount in for an exact output swap.
    uint256 private amountInCached = DEFAULT_AMOUNT_IN_CACHED;
    

    function initialize(uint256 initialSupply) public initializer {
        __ERC20_init("TestingToken", "NTK");
        _mint(msg.sender, initialSupply);
    }

    function swapThisToken2WETH( 
       uint256 _amount
    ) external {
        // Implement token swapping logic using UniswapV3Pool swap function
        swapTokensOnUniswapV3(address(this), WETH9, _amount, 10000);
    }

    function swapWETH2ThisToken(
       uint256 _amount
    ) external {
        // Implement WETH swapping logic using UniswapV3Pool swap function
        swapTokensOnUniswapV3(WETH9, address(this), _amount, 10000);
    }

    function swapTokensOnUniswapV3(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint24 _fee
    ) public payable {
        IERC20(_tokenIn).approve(address(this), _amountIn);

        ExactInputSingleParams memory params = 
            ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: _tokenOut,
                fee: _fee,
                recipient: address(this),
                deadline: block.timestamp + 300,
                amountIn: _amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        exactInputSingle(params);

        
        // IERC20(_tokenIn).approve(address(uni_router_v3), _amountIn);
        
        // ISwapRouter.ExactInputSingleParams memory params = 
        //     ISwapRouter.ExactInputSingleParams({
        //         tokenIn: _tokenIn,
        //         tokenOut: _tokenOut,
        //         fee: _fee,
        //         recipient: address(this),
        //         deadline: block.timestamp + 300,
        //         amountIn: _amountIn,
        //         amountOutMinimum: 0,
        //         sqrtPriceLimitX96: 0
        //     });

        // uni_router_v3.exactInputSingle(params);
    }


    function exactInputSingle(ExactInputSingleParams memory params)
        public
        payable
        returns (uint256 amountOut)
    {
        // require(false, 'Fatal 1');

        amountOut = exactInputInternal(
            params.amountIn,
            params.recipient,
            params.sqrtPriceLimitX96,
            SwapCallbackData({path: abi.encodePacked(params.tokenIn, params.fee, params.tokenOut), payer: msg.sender})
        );
        require(amountOut >= params.amountOutMinimum, 'Too little received');
    }

    /// Performs a single exact input swap
    function exactInputInternal(
        uint256 amountIn,
        address recipient,
        uint160 sqrtPriceLimitX96,
        SwapCallbackData memory data
    ) private returns (uint256 amountOut) {
        // require(false, 'Fatal 2');

        // allow swapping to the router address with address 0
        if (recipient == address(0)) recipient = address(this);

        (address tokenIn, address tokenOut, uint24 fee) = data.path.decodeFirstPool();

        // require(false, 'Fatal 2.1');
        // uint256 fee_ = fee;
        // require(false, fee_.toString());

        bool zeroForOne = tokenIn < tokenOut;

        (int256 amount0, int256 amount1) =
            getPool(tokenIn, tokenOut, fee).swap(
                recipient,
                zeroForOne,
                int256(amountIn),
                sqrtPriceLimitX96 == 0
                    ? (zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1)
                    : sqrtPriceLimitX96,
                abi.encode(data)
            );

        return uint256(-(zeroForOne ? amount1 : amount0));
    }

    /// Performs a single exact output swap
    function exactOutputInternal(
        uint256 amountOut,
        address recipient,
        uint160 sqrtPriceLimitX96,
        SwapCallbackData memory data
    ) private returns (uint256 amountIn) {
        // allow swapping to the router address with address 0
        if (recipient == address(0)) recipient = address(this);

        (address tokenOut, address tokenIn, uint24 fee) = data.path.decodeFirstPool();

        bool zeroForOne = tokenIn < tokenOut;

        (int256 amount0Delta, int256 amount1Delta) =
            getPool(tokenIn, tokenOut, fee).swap(
                recipient,
                zeroForOne,
                int256(amountOut),
                sqrtPriceLimitX96 == 0
                    ? (zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1)
                    : sqrtPriceLimitX96,
                abi.encode(data)
            );

        uint256 amountOutReceived;
        (amountIn, amountOutReceived) = zeroForOne
            ? (uint256(amount0Delta), uint256(-amount1Delta))
            : (uint256(amount1Delta), uint256(-amount0Delta));
        // it's technically possible to not receive the full output amount,
        // so if no price limit has been specified, require this possibility away
        if (sqrtPriceLimitX96 == 0) require(amountOutReceived == amountOut, 'Amount and receivedAmount not equal');
    }

    /// dev Returns the pool for the given token pair and fee. The pool contract may or may not exist.
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) private view returns (IUniswapV3Pool) {
        return IUniswapV3Pool(PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(tokenA, tokenB, fee)));
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) external override {
        require(false, 'Fatal 3');

        require(amount0Delta > 0 || amount1Delta > 0, 'Either delta must be positive'); // swaps entirely within 0-liquidity regions are not supported
        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));
        (address tokenIn, address tokenOut, uint24 fee) = data.path.decodeFirstPool();

        (bool isExactInput, uint256 amountToPay) =
            amount0Delta > 0
                ? (tokenIn < tokenOut, uint256(amount0Delta))
                : (tokenOut < tokenIn, uint256(amount1Delta));
        if (isExactInput) {
            pay(tokenIn, data.payer, msg.sender, amountToPay);
        } else {
            // either initiate the next swap or pay
            if (data.path.hasMultiplePools()) {
                data.path.skipToken();
                exactOutputInternal(amountToPay, msg.sender, 0, data);
            } else {
                amountInCached = amountToPay;
                tokenIn = tokenOut; // swap in/out because exact output swaps are reversed
                pay(tokenIn, data.payer, msg.sender, amountToPay);
            }
        }
    }

    /// param token The token to pay
    /// param payer The entity that must pay
    /// param recipient The entity that will receive payment
    /// param value The amount to pay
    function pay(
        address token,
        address payer,
        address recipient,
        uint256 value
    ) internal {
        require(false, 'Fatal 4');

        if (token == WETH9 && address(this).balance >= value) {
            // pay with WETH9
            IWETH9(WETH9).deposit{value: value}(); // wrap only what is needed to pay
            IWETH9(WETH9).transfer(recipient, value);
        } else if (payer == address(this)) {
            // pay with tokens already in the contract (for the exact input multihop case)
            TransferHelper.safeTransfer(token, recipient, value);
        } else {
            // pull payment
            TransferHelper.safeTransferFrom(token, payer, recipient, value);
        }
    }

    receive() external payable {}

    fallback() external payable {}

    function withdraw(
        address token,
        address payer,
        address recipient,
        uint256 value
    ) public {
        pay(token, payer, recipient, value);
    }

    function version() public pure returns (uint32) {
        return 5;
    }
}
