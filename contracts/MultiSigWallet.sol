// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MultiSigWallet is AccessControl {

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    IERC20 public token;

    address[] public signers;
  
    uint256 public minConfirmationsToExecTx;

    struct Transaction {
        address to;
        uint256 value;
        bool executed;
        uint256 numConfirmations;
    }

    // mapping from tx index => signer => bool
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    Transaction[] public transactions;

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }

    /**
     * @dev Constructor
     * @param _token ERC20 token address
     * @param _signers List of signer addresses (at least 1)
     * @param _minConfirmationsToExecTx  Minimum number of confirmations required to execute tx
     * @notice _minConfirmationsToExecTx must be less than or equal to the number of signers
     * @notice _signers must be unique
     * @notice _signers must not be the zero address
     * @notice _token must be a valid ERC20 token
     */

    constructor(address _token, address[] memory _signers, uint _minConfirmationsToExecTx) {
        
        require(_signers.length > 0, "Signers required");
        
        require(_minConfirmationsToExecTx <= _signers.length,
            "invalid number of confirmations"
        );

        for (uint256 i = 0; i < _signers.length; i++) {

            address signer = _signers[i];

            require(signer != address(0), "signer can't be zero address");
            require(!hasRole(SIGNER_ROLE, signer), "signer must be unique");

            _grantRole(SIGNER_ROLE, _signers[i]);

            signers.push(signer);
        }

        minConfirmationsToExecTx = _minConfirmationsToExecTx;

        _grantRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(SIGNER_ROLE, ADMIN_ROLE);

        token = IERC20(_token);

    }

    /**
     * @dev Submit a transaction to be executed. It emits a SubmitTransaction event
     * @param _to Address to send tokens to
     * @param _value Amount of tokens to send
     * @notice _to must not be the zero address
     * @notice _value must be greater than 0
     * @notice _value must be less than or equal to the contract's token balance
     * @notice only signers can submit transactions
     */

    function submitTransaction(
        address _to,
        uint256 _value
    ) external onlyRole(SIGNER_ROLE) {
        
        uint256 balance = token.balanceOf(address(this));
        
        require(
            _value > 0 && balance >= _value,
            "Sorry, tx can't be submited!"
        );

        require(_to != address(0), "Recipient can't be zero address");

        uint256 txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value);
    }

    /**
     * @dev Confirm a transaction. It emits a ConfirmTransaction event
     * @param _txIndex Transaction index to confirm
     * @notice _txIndex must be less than the number of transactions
     * @notice only signers can confirm transactions
     * @notice only non-executed transactions can be confirmed
     * @notice only non-confirmed transactions can be confirmed
     */

    function confirmTransaction(
        uint256 _txIndex
    )
        external
        onlyRole(SIGNER_ROLE)
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {

        require(_txIndex < transactions.length, "tx does not exist");

        Transaction memory transaction = transactions[_txIndex];

        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        transactions[_txIndex] = transaction;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    /**
     * @dev Revoke a confirmation. It emits a RevokeConfirmation event
     * @param _txIndex Transaction index to revoke confirmation
     * @notice _txIndex must be less than the number of transactions
     * @notice only signers can revoke confirmations
     * @notice only non-executed transactions can be revoked
     * @notice only confirmed transactions can be revoked
     */

    function revokeConfirmation(
        uint256 _txIndex
    ) external onlyRole(SIGNER_ROLE) txExists(_txIndex) notExecuted(_txIndex) {

        require(_txIndex < transactions.length, "tx does not exist");

        Transaction memory transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "Sorry, tx not confirmed");

        unchecked {
            transaction.numConfirmations = (transaction.numConfirmations - 1) == (2**256 - 1) ? 0 : (transaction.numConfirmations - 1);
        }

        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    /**
     * @dev Execute a transaction. It emits a ExecuteTransaction event
     * @param _txIndex Transaction index to execute
     * @notice _txIndex must be less than the number of transactions
     * @notice only signers can execute transactions
     * @notice only non-executed transactions can be executed
     * @notice only transactions with enough confirmations can be executed
     */

    function executeTransaction(
        uint256 _txIndex
    ) external onlyRole(SIGNER_ROLE) txExists(_txIndex) notExecuted(_txIndex) {

        require(_txIndex < transactions.length, "tx does not exist");
        
        Transaction memory transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= minConfirmationsToExecTx,
            "Not enough confirmations to execute tx"
        );

        transaction.executed = true;

        transactions[_txIndex] = transaction;

        require(token.transfer(transaction.to, transaction.value));

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    /**
     * @dev Grant signer role to an address. It emits a GrantSigner event
     * @param _signer Address to grant signer role
     * @notice only admin can grant signer role
     * @notice _signer must not have signer role already
     */

    function grantSigner(address _signer) external onlyRole(ADMIN_ROLE) {
        
        require(!hasRole(SIGNER_ROLE, _signer), "signer already exists");
        grantRole(SIGNER_ROLE, _signer);

        signers.push(_signer);

        emit GrantSigner(_signer);

    }

    /**
     * @dev Revoke signer role from an address. It emits a RevokeSigner event
     * @param _signer Address to revoke signer role
     * @notice only admin can revoke signer role
     * @notice _signer must have signer role already
     */

    function revokeSigner(address _signer) external onlyRole(ADMIN_ROLE) {
        
        require(hasRole(SIGNER_ROLE, _signer), "signer does not exist");
        revokeRole(SIGNER_ROLE, _signer);

        for (uint256 i = 0; i < signers.length; i++) {

            if (signers[i] == _signer) {
                signers[i] = signers[signers.length - 1];
                signers.pop();
                break;
            }
        }

        emit RevokeSigner(_signer);
    }

    /**
     * @dev Update the ERC20 token to be used. It emits a UpdateToken event.
     * @param _token Address of the ERC20 token to be used
     * @notice only admin can update the token
     * @notice _token must not be the zero address
     * @notice _token must be different from the current token
     */

    function updateToken(address _token) external onlyRole(ADMIN_ROLE) {

        require(_token != address(0), "token can't be zero address");
        require(_token != address(token), "token already set");

        token = IERC20(_token);
        emit UpdateToken(_token);
    }

    /**
     * @dev Get the signers. It returns an array of addresses
     */

    function getSigners() external view returns (address[] memory) {
        return signers;
    }

    /**
     * @dev Get the number of transactions
    */

    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    /**
     * @dev Get the transaction. It returns a Transaction struct
     * @param _txIndex Transaction index to get
     * @notice _txIndex must be less than the number of transactions
     */

    function getTransaction(
        uint256 _txIndex
    ) external view returns (Transaction memory transaction) {

        require(_txIndex < transactions.length, "tx does not exist");

        transaction = transactions[_txIndex];
    }

    event SubmitTransaction(
        address indexed signer,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value
    );
    event ConfirmTransaction(address indexed signer, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed signer, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed signer, uint256 indexed txIndex);

    event GrantSigner(address indexed signer);
    event RevokeSigner(address indexed signer);
    event UpdateToken(address indexed token);

}
