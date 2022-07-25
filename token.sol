
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '../interfaces/erc20_interface.sol';
import '../libraries/safe_math.sol';
 

contract RCoin is IERC20 {
    using SafeMath for uint;

    string public constant symbol = 'RC';                
    string public constant name = 'RCoin';       
    uint8 public constant decimals = 18;                

    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;

    uint public _totalSupply;
    bool public disabled;
    
    address public admin;

    constructor() {
        _totalSupply = 0;
        disabled = false;
        balances[msg.sender] = 0;  
        admin = msg.sender;                
    }

    modifier AdminOnly {
        require(msg.sender == admin);
        _;
    }



    // Function _mint: Create more of your tokens.

    function _mint(uint amount) 
        public 
        AdminOnly
    {
        balances[admin] = balances[admin].add(amount);
        transfer(admin, amount);
        emit Transfer(msg.sender, admin, amount);
        _totalSupply = _totalSupply.add(amount);
    }

    // Function _disable_mint: Disable future minting of your token.

    function _disable_mint()
        public
        AdminOnly
    {
        disabled = true;
    }


    // ============================================================
    //               STANDARD ERC-20 IMPLEMENTATION  
    // ============================================================
    
    // return total supply of the token
    function totalSupply() 
        public 
        override
        view 
        returns (uint) 
    {
        return _totalSupply;
    }
 
    // return number of tokens held by account
    function balanceOf(address account) 
        public
        override 
        view 
        returns (uint) 
    {
        return balances[account];
    }
 
    // transfer numTokens from msg.sender to receiver
    function transfer(address receiver, uint numTokens) 
        public
        override 
        returns (bool) 
    {
        require(numTokens <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(numTokens);
        balances[receiver] = balances[receiver].add(numTokens);
        emit Transfer(msg.sender, receiver, numTokens);
        return true;
    }
 
    // approve delegate to send up to numTokens on behalf of msg.sender
    function approve(address delegate, uint numTokens) 
        public 
        override 
        returns (bool) 
    {
        allowed[msg.sender][delegate] = numTokens;
        emit Approval(msg.sender, delegate, numTokens);
        return true;
    }

    // check how many tokens delegate is allowed to send on behalf of owner
    function allowance(address owner, address delegate) 
        public
        override 
        view 
        returns (uint) 
    {
        return allowed[owner][delegate];
    }
 
    // transfer numTokens from owner to buyer
    function transferFrom(address owner, address buyer, uint numTokens) 
        public
        override 
        returns (bool) 
    {
        require(numTokens <= balances[owner], "test");
        require(numTokens <= allowed[owner][msg.sender], "test2");
        balances[owner] = balances[owner].sub(numTokens);
        allowed[owner][msg.sender] = allowed[owner][msg.sender].sub(numTokens);
        balances[buyer] = balances[buyer].add(numTokens);
        emit Transfer(owner, buyer, numTokens);
        return true;
    }
}
