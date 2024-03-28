// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from 'forge-std/Test.sol';

import {VariableDebtToken} from '../src/contracts/VariableDebtToken.sol';
import {Test,console} from 'forge-std/Test.sol';
import {IPool} from 'lib/aave-v3-core/contracts/interfaces/IPool.sol';
import {IAaveIncentivesController} from 'lib/aave-v3-core/contracts/interfaces/IAaveIncentivesController.sol';


interface Iproxy {
  function upgradeTo(address newImplementation) external;
  function balanceOf(address user) external view returns (uint256); 
  function approve(address spender, uint256 amount) external returns (bool);
  function transferFrom(address from, address to, uint256 value) external returns (bool);
  function transfer(address recipient, uint256 amount) external returns (bool);
  function getAllowance(address borrower, address user) external view returns(uint);
}

contract VariableDebtTokenTest is Test {


  VariableDebtToken variableDebtToken_;
   address borrower = 0x1e38f19EC613cFCb06D23fd71d01C9dC1fEba45e;
   address debtPayer = 0xAe2D4617c862309A3d75A0fFB358c7a5009c673F;
   
  //  address Tenant = mkaddr("Tenant");
  // address Estate = mkaddr("Estate");

    address main =0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address underlyingAsset = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address incentivesController = 0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb;
    uint8 debtTokenDecimals = 6;
    string debtTokenName = 'USDCMOCK';
    string debtTokenSymbol = 'USD';
    address admin = 0x64b761D848206f447Fe2dd461b0c635Ec39EbB27;
    address proxyaddress = 0x72E95b8931767C79bA4EeE721354d6E99a61D004;



  function setUp() public {
    vm.startPrank(main);
    vm.createSelectFork("https://eth-mainnet.g.alchemy.com/v2/xypdsCZYrlk6oNi93UmpUzKE9kmxHy2n", 19511981);
    variableDebtToken_ = new VariableDebtToken(IPool(main)); 
    
    variableDebtToken_.initialize(IPool(main), underlyingAsset, IAaveIncentivesController(incentivesController), debtTokenDecimals, debtTokenName, debtTokenSymbol, '');
    vm.stopPrank();  
    //upgrade aave variable debt implementation contract 
    vm.startPrank(admin);
    Iproxy(proxyaddress).upgradeTo(address(variableDebtToken_));
    vm.stopPrank();
  }

       

     function testBorrowAndDebtTransfer() public{
      vm.startPrank(borrower);
      IPool(main).borrow(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 600000000, 2, 0, 	0x1e38f19EC613cFCb06D23fd71d01C9dC1fEba45e);
      
      uint debtbeforeTransfer = Iproxy(proxyaddress).balanceOf(borrower);
      console.log('varibleDebt token of borrower before transfer', debtbeforeTransfer);

      uint debtpayerbeforeTransfer = Iproxy(proxyaddress).balanceOf(debtPayer);
      console.log('varibleDebt token of debtpayer before transfer', debtpayerbeforeTransfer);

      Iproxy(proxyaddress).approve(debtPayer, 11743700162 );
      vm.stopPrank();
      
      vm.startPrank(debtPayer);
      Iproxy(proxyaddress).transferFrom(borrower, debtPayer, 11743700162);

      vm.stopPrank();

           
      vm.startPrank(debtPayer);
      uint debtafterTransfer = Iproxy(proxyaddress).balanceOf(borrower);
      console.log('variable Debt token of borrower after transfer', debtafterTransfer);

      uint debtpayerafterTransfer = Iproxy(proxyaddress).balanceOf(debtPayer);
      console.log('variable debt token of debt payer after transfer', debtpayerafterTransfer);
   
      Iproxy(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).approve(main, 11743700162000000000000000000000000000000 );
      IPool(main).repay(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 600000000, 2, debtPayer);
      vm.stopPrank();
      console.log('debt repayment successful');
      }

      function mkaddr(string memory name) public returns (address) {
        address addr = address(
            uint160(uint256(keccak256(abi.encodePacked(name))))
        );
          vm.label(addr, name);
        return addr;
    }

}