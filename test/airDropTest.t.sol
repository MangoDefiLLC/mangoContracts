pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

contract airDrop is Test {
    string public BASE;
    uint256 public baseFork;

    function setUp() public{
        BASE = vm.envString("BASE_RPC");
        baseFork = vm.createFork(BASE);
    }
    // demonstrate fork ids are unique
    function testForkIdDiffer() public {
        assert(baseFork == baseFork);
    }
 
    // select a specific fork
    function selectFork(uint256 _fork) public {
        // select the fork
        vm.selectFork(_fork);
        assertEq(vm.activeFork(), _fork);
 
        // from here on data is fetched from the `mainnetFork` if the EVM requests it and written to the storage of `mainnetFork`
    }

}