// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";


contract TestingTokenProxy is TransparentUpgradeableProxy {
    // address public implementation;
    
    // event Upgraded(address indexed implementation);

    
    // constructor(address _implementation) {
    //     implementation = _implementation;
    // }

    // function upgradeTo(address _implementation) public {
    //     require(implementation != _implementation);
    //     implementation = _implementation;
    //     emit Upgraded(implementation);
    // }

    // fallback () external payable {
    //     address implementation_ = implementation;
    //     require(implementation_ != address(0));
    //     bytes memory data = msg.data;

    //     assembly {
    //         let result := delegatecall(gas(), implementation_, add(data, 0x20), mload(data), 0, 0)
    //         let size := returndatasize()
    //         let ptr := mload(0x40)
    //         returndatacopy(ptr, 0, size)
    //         switch result
    //         case 0 { revert(ptr, size) }
    //         default { return(ptr, size) }
    //     }
    // }

    // receive() external payable { }


    constructor(address _logic, address _admin, bytes memory _data)
        public 
        payable 
        TransparentUpgradeableProxy(_logic, _admin, _data)
    {
        
    }
}
