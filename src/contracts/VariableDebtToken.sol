  // SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;
import {Test,console} from 'forge-std/Test.sol';



import {WadRayMath} from 'lib/aave-v3-core/contracts/protocol/libraries/math/WadRayMath.sol';
import {ScaledBalanceTokenBase} from 'lib/aave-v3-core/contracts/protocol/tokenization/base/ScaledBalanceTokenBase.sol';
import {IVariableDebtToken} from 'lib/aave-v3-core/contracts/interfaces/IVariableDebtToken.sol';
import {IAaveIncentivesController} from 'lib/aave-v3-core/contracts/interfaces/IAaveIncentivesController.sol';
import {IPool} from 'lib/aave-v3-core/contracts/interfaces/IPool.sol';
import {Errors} from  'lib/aave-v3-core/contracts/protocol/libraries/helpers/Errors.sol';
import {DebtTokenBase} from 'lib/aave-v3-core/contracts/protocol/tokenization/base/DebtTokenBase.sol';
import {EIP712Base} from 'lib/aave-v3-core/contracts/protocol/tokenization/base/EIP712Base.sol';
import {IInitializableDebtToken} from 'lib/aave-v3-core/contracts/interfaces/IInitializableDebtToken.sol';
import {VersionedInitializable} from 'lib/aave-v3-core/contracts/protocol/libraries/aave-upgradeability/VersionedInitializable.sol';
import {WadRayMath} from  'lib/aave-v3-core/contracts/protocol/libraries/math/WadRayMath.sol';
import {SafeCast} from 'lib/openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
 import {ERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import {IERC20} from 'lib/aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IERC20Errors} from 'lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol';

/**
 * @title VariableDebtToken
 * @author Aave
 * @notice Implements a variable debt token to track the borrowing positions of users
 * at variable rate mode
 * @dev Transfer and approve functionalities are disabled since its a non-transferable token
 */

 

 contract VariableDebtToken is DebtTokenBase, ScaledBalanceTokenBase, IVariableDebtToken, IERC20Errors {

  using WadRayMath for uint256;
  using SafeCast for uint256;

  uint256 public constant DEBT_TOKEN_REVISION = 0x1;

  /**
   * @dev Constructor.
   * @param pool The address of the Pool contract
   */
  
  constructor( IPool pool )

    DebtTokenBase()
    ScaledBalanceTokenBase(pool, 'VARIABLE_DEBT_TOKEN_IMPL', 'VARIABLE_DEBT_TOKEN_IMPL', 0)
  {
    // Intentionally left blank
  }



  /// @inheritdoc IInitializableDebtToken
  function initialize(
    IPool initializingPool,
    address underlyingAsset,
    IAaveIncentivesController incentivesController,
    uint8 debtTokenDecimals,
    string memory debtTokenName,
    string memory debtTokenSymbol,
    bytes calldata params
  ) external override initializer {
    require(initializingPool == POOL, Errors.POOL_ADDRESSES_DO_NOT_MATCH);
    _setName(debtTokenName);
    _setSymbol(debtTokenSymbol);
    _setDecimals(debtTokenDecimals);

    _underlyingAsset = underlyingAsset;
    _incentivesController = incentivesController;

    _domainSeparator = _calculateDomainSeparator();

    emit Initialized(
      underlyingAsset,
      address(POOL),
      address(incentivesController),
      debtTokenDecimals,
      debtTokenName,
      debtTokenSymbol,
      params
    );
  }

   // Define a mapping to track allowed transfers
    mapping(address =>  mapping(address => uint256)) public _allowedTransfers;


    //  uint256 internal _totalSupply;

  /// @inheritdoc VersionedInitializable
  function getRevision() internal pure virtual override returns (uint256) {
    return DEBT_TOKEN_REVISION;
  }

  function getAllowance(address borrower, address user) external view returns(uint) {
    return _allowedTransfers[borrower][user];
  }

  function balanceOf(address user) public view virtual override returns (uint256) {
    uint256 scaledBalance = super.balanceOf(user);

    if (scaledBalance == 0) {
      return 0;
    }

    return scaledBalance.rayMul(POOL.getReserveNormalizedVariableDebt(_underlyingAsset));
  }

  //  function balanceOf(address account) public view virtual override returns (uint256) {
  //       return _userState[account].balance;
  //   }

  /// @inheritdoc IVariableDebtToken
  function mint(
    address user,
    address onBehalfOf,
    uint256 amount,
    uint256 index
  ) external virtual override onlyPool returns (bool, uint256) {
    if (user != onBehalfOf) {
      _decreaseBorrowAllowance(onBehalfOf, user, amount);
    }
    return (_mintScaled(user, onBehalfOf, amount, index), scaledTotalSupply());
  }

  /// @inheritdoc IVariableDebtToken
  function burn(
    address from,
    uint256 amount,
    uint256 index
  ) external virtual override onlyPool returns (uint256) {
    _burnScaled(from, address(0), amount, index);
    return scaledTotalSupply();
  }


  function totalSupply() public view virtual override returns (uint256) {
    return super.totalSupply().rayMul(POOL.getReserveNormalizedVariableDebt(_underlyingAsset));
  }

  /// @inheritdoc EIP712Base
  function _EIP712BaseId() internal view override returns (string memory) {
    return name();
  }

  // /**
  //  * @dev Being non transferrable, the debt token does not implement any of the
  //  * standard ERC20 functions for transfer and allowance.
  //  */
  // function transfer(address, uint256) external virtual override returns (bool) {
  //   revert(Errors.OPERATION_NOT_SUPPORTED);
  // }

    /**
   * @dev Implements ERC20 transfer functionality
   */
  

      /**
     * @dev ERC20 allowance functionality
     * @param owner The address that approves spending the tokens
     * @param spender The address approved to spend the tokens
     * @return The remaining allowance for the spender
     */
    function allowance(address owner, address spender) external view virtual override returns (uint256) {
        return _allowedTransfers[owner][spender];
    }

   /**
     * @dev ERC20 approve functionality with additional security checks
     * @param spender The address to approve for spending the tokens
     * @param amount The amount of tokens to approve
     * @return A boolean indicating success or failure
     */
    function approve(address spender, uint256 amount) external virtual override returns (bool) {
        _allowedTransfers[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal virtual  {
     if (from == address(0)) {
       
        _totalSupply += value;
     } else {
        uint128 fromBalance = _userState[from].balance;
        if (fromBalance < value) {
            revert ERC20InsufficientBalance(from, fromBalance, value);
        }
        unchecked {
            
            _userState[from].balance = uint128(fromBalance - value);
         }
     }

    if (to == address(0)) {
        unchecked {
            _totalSupply -= value;
        }
    } else {
        unchecked {
          
          uint128 tobal = _userState[to].balance += uint128(value);
        }
    }
    
    emit Transfer(from, to, value);
}

    function transferFrom(address from, address to, uint256 value) public virtual override returns (bool) {
        address spender = _msgSender();
         require(spender == to, "Only recipient can transfer debt");
     require(_allowedTransfers[from][msg.sender] >= value, "insuddicient allowance");
        _transfer(from, to, value);
        _allowedTransfers[from][to] -= uint128(value);
        return true;
      
    }

  function increaseAllowance(address, uint256) external virtual override returns (bool) {
    revert(Errors.OPERATION_NOT_SUPPORTED);
  }

  function decreaseAllowance(address, uint256) external virtual override returns (bool) {
    revert(Errors.OPERATION_NOT_SUPPORTED);
  }

  /// @inheritdoc IVariableDebtToken
  function UNDERLYING_ASSET_ADDRESS() external view override returns (address) {
    return _underlyingAsset;
  }
  function transfer(address recipient, uint256 amount) external virtual override returns (bool) {
   revert(Errors.OPERATION_NOT_SUPPORTED);
  }
}