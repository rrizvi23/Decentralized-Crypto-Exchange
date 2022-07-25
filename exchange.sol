
pragma solidity ^0.8.0;

import '../interfaces/erc20_interface.sol';
import '../libraries/safe_math.sol';
import './token.sol';


contract TokenExchange {
    using SafeMath for uint;
    address public admin;

    address tokenAddr = 0x2cD37Ee5E08fA7F3346Ef94eaB991Ec4950b00d2;                             
    RCoin private token = RCoin(tokenAddr);               

    // Liquidity pool for the exchange
    uint public token_reserves = 0;
    uint public eth_reserves = 0;
    
    mapping(address => uint) public liquidity_pool; // keeps track of how much liquidity each address is entitled to (sqrt(RC*ETH))

    // Constant: x * y = k
    uint public k;
    
    // liquidity rewards
    uint private swap_fee_numerator = 0;     
    uint private swap_fee_denominator = 100;
    
    event AddLiquidity(address from, uint amount);
    event RemoveLiquidity(address to, uint amount);
    event Received(address from, uint amountETH);

    constructor() 
    {
        admin = msg.sender;
    }
    
    modifier AdminOnly {
        require(msg.sender == admin, "Only admin can use this function!");
        _;
    }

    // Used for receiving ETH
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
    fallback() external payable{}

    // Function createPool: Initializes a liquidity pool between your Token and ETH.
    // ETH will be sent to pool in this transaction as msg.value
    // amountTokens specifies the amount of tokens to transfer from the liquidity provider.
    // Sets up the initial exchange rate for the pool by setting amount of token and amount of ETH.
    function createPool(uint amountTokens)
        external
        payable
        AdminOnly
    {
        // require pool does not yet exist
        require (token_reserves == 0, "Token reserves was not 0");
        require (eth_reserves == 0, "ETH reserves was not 0.");

        // require nonzero values were sent
        require (msg.value > 0, "Need ETH to create pool.");
        require (amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        eth_reserves = msg.value;
        token_reserves = amountTokens;
        k = eth_reserves.mul(token_reserves);
        //require(sqrt(token_reserves.mul(eth_reserves)) != 0, "i have no idea what im doing");
        liquidity_pool[msg.sender] = liquidity_pool[msg.sender].add((sqrt(token_reserves.mul(eth_reserves))).mul(5000000000000000));
        //liquidity_pool[msg.sender] = 5000000000;

    }


    
    // Function priceToken: Calculate the price of your token in ETH.
    function priceToken()
        public
        view
        returns (uint)
    {
       
        require (eth_reserves > 0);
        require (token_reserves > 0);
        return eth_reserves.mul(1000000).div(token_reserves);

    }

    // Function priceETH: Calculate the price of ETH for your token.
    function priceETH()
        public
        view
        returns (uint)
    {
        require (eth_reserves > 0);
        require (token_reserves > 0);
        return token_reserves.mul(1000000).div(eth_reserves);
    }


    /* ========================= Liquidity Provider Functions =========================  */

    // Function addLiquidity: Adds liquidity given a supply of ETH (sent to the contract as msg.value)
    function addLiquidity(uint max_exchange_rate, uint min_exchange_rate)
        external
        payable
    {

        require (msg.value > 0);
        uint token_liquidity = msg.value.mul(priceETH()).div(1000000);
        require (token_liquidity <= token.balanceOf(msg.sender)); // check token reserve
        require((eth_reserves.add(msg.value)).mul(100).div(token_reserves.add(token_liquidity)) < max_exchange_rate);
        require((eth_reserves.add(msg.value)).mul(100).div(token_reserves.add(token_liquidity)) > min_exchange_rate);
        eth_reserves = eth_reserves.add(msg.value);
        emit Received(msg.sender, msg.value);
        token.transferFrom(msg.sender, address(this), token_liquidity); 
        token_reserves = token_reserves.add(token_liquidity);
        k = eth_reserves.mul(token_reserves);
        
        // update liquidity_pool
        liquidity_pool[msg.sender] = liquidity_pool[msg.sender].add(sqrt(token_liquidity.mul(msg.value)));
        
        emit AddLiquidity(msg.sender, token_liquidity);
    }


    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove.
    function removeLiquidity(uint amountETH, uint max_exchange_rate, uint min_exchange_rate)
        public 
        payable
    {

        require (amountETH > 0, "test10");
        uint token_liquidity = amountETH.mul(priceETH()).div(1000000);
        require (token_liquidity < token_reserves, "you are trying to empty the pool");
        require (liquidity_pool[msg.sender].mul(eth_reserves).div(sqrt(k)) >= amountETH, "test11"); // checks that we're entitled to this much
        require((eth_reserves.add(amountETH)).mul(100).div(token_reserves.add(token_liquidity)) < max_exchange_rate);
        require((eth_reserves.add(amountETH)).mul(100).div(token_reserves.add(token_liquidity)) > min_exchange_rate);
        token.transfer(msg.sender, token_liquidity);
    
        (bool success, ) = payable(msg.sender).call{value: amountETH}(""); // transfers ETH reserves
        require (success, "Failed to send ETH.");
        token_reserves = token_reserves.sub(token_liquidity);
        eth_reserves = eth_reserves.sub(amountETH);
        k = token_reserves.mul(eth_reserves);
        
        liquidity_pool[msg.sender] = liquidity_pool[msg.sender].sub(sqrt(amountETH.mul(token_liquidity)));
        
        emit RemoveLiquidity(msg.sender, token_liquidity);
    }

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    function removeAllLiquidity(uint max_exchange_rate, uint min_exchange_rate)
        external
        payable
    {

        //maxETH = liquidity_pool[msg.sender].mul(eth_reserves).div(sqrt(k))
        require(sqrt(k) > 0, "fuckmylife");
        require(liquidity_pool[msg.sender].div(sqrt(k)) != 1);
        removeLiquidity(liquidity_pool[msg.sender].mul(eth_reserves).div(sqrt(k)), max_exchange_rate, min_exchange_rate);
    }

    function sqrt(uint x) public pure returns (uint y) {
        uint z = x.add(1).div(2);
        y = x;
        while (z < y) {
            y = z;
            z = x.div(z).add(z).div(2);
        }
        //y = y.mul(1000000);
    }    



    /* ========================= Swap Functions =========================  */ 

    // Function swapTokensForETH: Swaps your token with ETH
    // You can change the inputs, or the scope of your function, as needed.
    function swapTokensForETH(uint amountTokens, uint max_exchange_rate)
        external 
        payable
    {

        require (amountTokens < token.balanceOf(msg.sender));
        require(amountTokens < token_reserves, "checker");
        uint amountETH = amountTokens.mul(priceToken()).div(1000000);
        require((eth_reserves.add(amountETH)).mul(100).div(token_reserves.add(amountTokens)) < max_exchange_rate, "slippage issue");
        require (amountETH < eth_reserves);
        
        token.transferFrom(msg.sender, address(this), amountTokens); 
        
        payable(msg.sender).transfer(amountETH); // transfers ETH reserves
        token_reserves = token_reserves.add(amountTokens);
        eth_reserves = eth_reserves.sub(amountETH);
        


        /***************************/
        /* Check for x * y == k, assuming x and y are rounded to the nearest integer. */
        // Check for Math.abs(token_reserves * eth_reserves - k) < (token_reserves + eth_reserves + 1));
        //   to account for the small decimal errors during uint division rounding.
        uint check = token_reserves.mul(eth_reserves);
        if (check >= k) {
            check = check.sub(k);
        }
        else {
            check = k.sub(check);
        }
        assert(check < (token_reserves.add(eth_reserves).add(1)));
    }



    // Function swapETHForTokens: Swaps ETH for your tokens.
    // ETH is sent to contract as msg.value.
    function swapETHForTokens(uint max_exchange_rate)
        external
        payable 
    {

        uint amountTokens = msg.value.mul(priceETH()).div(1000000);
        require((token_reserves.add(amountTokens)).mul(100).div(eth_reserves.add(msg.value)) < max_exchange_rate, "slippage issue2");
        require (amountTokens < token_reserves);
        token.transfer(msg.sender, amountTokens);
        token_reserves = token_reserves.sub(amountTokens);
        eth_reserves = eth_reserves.add(msg.value);
        emit Received(msg.sender, msg.value);
        

        /**************************/

        /* Check for x * y == k, assuming x and y are rounded to the nearest integer. */
        // Check for Math.abs(token_reserves * eth_reserves - k) < (token_reserves + eth_reserves + 1));
        //   to account for the small decimal errors during uint division rounding.
        uint check = token_reserves.mul(eth_reserves);
        if (check >= k) {
            check = check.sub(k);
        }
        else {
            check = k.sub(check);
        }
        assert(check < (token_reserves.add(eth_reserves).add(1)));
    }

    /***  Define helper functions for swaps here as needed: ***/
}
