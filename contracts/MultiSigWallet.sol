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

    function confirmTransaction(
        uint256 _txIndex
    )
        external
        onlyRole(SIGNER_ROLE)
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction memory transaction = transactions[_txIndex];

        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        transactions[_txIndex] = transaction;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(
        uint256 _txIndex
    ) external onlyRole(SIGNER_ROLE) txExists(_txIndex) notExecuted(_txIndex) {
        
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

    function revokeConfirmation(
        uint256 _txIndex
    ) external onlyRole(SIGNER_ROLE) txExists(_txIndex) notExecuted(_txIndex) {

        Transaction memory transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "Sorry, tx not confirmed");

        unchecked {
            transaction.numConfirmations = (transaction.numConfirmations - 1) == (2**256 - 1) ? 0 : (transaction.numConfirmations - 1);
        }

        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function grantSigner(address _signer) external onlyRole(ADMIN_ROLE) {
        
        require(!hasRole(SIGNER_ROLE, _signer), "signer already exists");
        grantRole(SIGNER_ROLE, _signer);

        signers.push(_signer);

    }

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

    function updateToken(address _token) external onlyRole(ADMIN_ROLE) {
        token = IERC20(_token);
    }

    function getSigners() public view returns (address[] memory) {
        return signers;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(
        uint256 _txIndex
    ) public view returns (Transaction memory transaction) {
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
    event RevokeSigner(address indexed signer);
}
