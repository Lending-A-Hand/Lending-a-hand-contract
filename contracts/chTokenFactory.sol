// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./RToken/RToken.sol";

contract chTokenFactory is Ownable{ 
    
    RToken[] public rTokenRecord;
    function newChToken(
        IAllocationStrategy _strategy,
        string memory _name,
        string memory _symbol
    )   external
        onlyOwner
    {
        RToken newToken = new RToken();
        newToken.initialize(
            _strategy,
            _name,
            _symbol,
            18
        );
        rTokenRecord.push(newToken);
    }

}
