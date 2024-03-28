// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {VariableDebtToken} from '../src/contracts/VariableDebtToken.sol';
import {Script} from 'forge-std/Script.sol';

contract Deploy is Script {
  function run() public {
    vm.startBroadcast();
    // new VariableDebtToken();
    vm.stopBroadcast();
  }
}
