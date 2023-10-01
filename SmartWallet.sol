// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

contract ReentrancyGuard {
    bool private _notEntered = true;

    modifier nonReentrant() {
        require(_notEntered, "Reentrant call");
        _notEntered = false;
        _;
        _notEntered = true;
    }
}


contract AccountManager {
    

    // Manage each account and its balance.
    
    mapping(address => Account)  _accounts; 
    address ownerAccount;
    
    struct Account{
        // address Account;
        uint balance;
        uint depositIndex;
        uint withdrawalIndex;
        uint transferIndex;
        uint receivedIndex;
        mapping(uint => Transaction) deposits;
        mapping(uint => Transaction) withdrawels;
        mapping(uint => Transaction) transfers;
        mapping(uint => Transaction) recivings;


    }
    struct Transaction{
        uint amount;
        uint timestamp;
    }
    modifier onlyOwner(){
        require(msg.sender == ownerAccount, "You are not authorized");
        _;
    }
    

    modifier noEmptyAmount(uint amount){
        require(amount > 0,"Amount must be over 0");
        _;
    }


    modifier hasEnoughBalance(address user,uint amount){
        require(_accounts[user].balance >= amount,"Sent Ether does not match specified amount");
        _;
    }
}

contract WalletCore is AccountManager,ReentrancyGuard {
    constructor(address owner){
        ownerAccount = owner;

    }
    
    
    function _getAccountInfo(address account) external view onlyOwner returns(uint balance,uint depositIndex, uint withdrawalIndex,uint transferIndex,uint receivedIndex) {
        return( 
            _accounts[account].balance,
            _accounts[account].depositIndex,
            _accounts[account].withdrawalIndex,
            _accounts[account].transferIndex,
            _accounts[account].receivedIndex        
        ); 

    }


    //There should be the possibility to deposit 'money' into one's account.
    function deposit(address user,uint amount) external payable nonReentrant noEmptyAmount(amount)   {
        require(msg.value >= amount ,"Sent Ether does not match specified amount" );
        
        _accounts[user].balance += amount;
        Transaction memory deposited = Transaction(amount, block.timestamp);
        _accounts[user].deposits[_accounts[user].depositIndex] = deposited;
        _accounts[user].depositIndex++;

    }

    //Opportunity to withdraw 'money' from one's account as long as the account is not exceeded.
    function withdraw(address recipient,uint amount) external payable nonReentrant noEmptyAmount(amount) hasEnoughBalance(recipient,amount)  {

    
        _accounts[recipient].balance -= amount;
        Transaction memory withdrawal = Transaction(amount, block.timestamp);
        _accounts[recipient].withdrawels[_accounts[recipient].withdrawalIndex] = withdrawal;

        payable(recipient).transfer(amount); 
        _accounts[recipient].withdrawalIndex++;
    }


    // It should also be possible to transfer 'money' from one's account to someone else's account as long as there are assets to transfer.
    function transfer(address from,address to, uint amount) external nonReentrant noEmptyAmount(amount) hasEnoughBalance(from,amount)   {
        require(from != address(0), "Sender address is zero!");
        require(to != address(0), "Recipient address is zero!");
        require(from != to,"Cannot send to yourself");
    
     
        _accounts[from].balance -= amount;
        _accounts[to].balance += amount;
        Transaction memory transferal = Transaction(amount,block.timestamp);   
        _accounts[from].transfers[_accounts[from].transferIndex] = transferal;

        Transaction memory received = Transaction(amount,block.timestamp);   
        _accounts[to].recivings[_accounts[to].receivedIndex] = received;

        _accounts[from].transferIndex++;
        _accounts[to].receivedIndex++;
    }


    // only se balance of own account
    function _checkBalance(address account) external view onlyOwner returns(uint){
        return _accounts[account].balance;
    }
}

contract AccountInterface{

    
    event LogError(string reason);

    event TransactionProcessed(
        bool success,
        string action,
        uint timestamp,
        address sender,
        address recipient,
        uint amount 

    );
    event AccountInfo(
        bool succes,
        string action,
        uint balance,
        uint depositIndex, 
        uint withdrawalIndex,
        uint transferIndex,
        uint receivedIndex
    );
    event Balance(
        uint amount
    );
    
    
    
    WalletCore accountCore = new WalletCore(address(this));
   

    function deposit(uint amount) public payable returns(bool success) {
        try accountCore.deposit{value: msg.value}(msg.sender,amount){
            
            emit TransactionProcessed(true, "Deposit", block.timestamp, msg.sender, address(accountCore), amount);
            return true;
        } catch Error(string memory reason){ 
            emit LogError(reason);
            return false;
        } 
    }
    
    function withdraw(uint amount) public   returns(bool success){

        try accountCore.withdraw(msg.sender,amount){
            emit TransactionProcessed(true,"Withdraw", block.timestamp,address(accountCore),msg.sender, amount);
            return true;
        } catch Error(string memory reason){
            emit LogError(reason);
            return false;
        }
    }
    function transfer(address to,uint amount) public   returns(bool success){

        try accountCore.transfer(msg.sender,to,amount){
            emit TransactionProcessed(true,"Transfer", block.timestamp,msg.sender,to, amount);
            return true;
        } catch Error(string memory reason){
            emit LogError(reason);
            return false;
        }
    }

    function getAccountInfo() public returns(bool success) {
        try accountCore._getAccountInfo(msg.sender) returns(uint _balance, uint depositIndex, uint withdrawalIndex, uint transferIndex, uint _receivedIndex) {
            emit AccountInfo(true,"AccountInformation",_balance, depositIndex, withdrawalIndex, transferIndex, _receivedIndex);
            return true;
        } catch Error(string memory reason) {
            emit LogError(reason);
            return false;
        }
        
}
    function getBalance() public returns(bool success) {
        try accountCore._checkBalance(msg.sender) returns(uint amount)  {
            emit Balance(amount);
            return true;
        } catch Error(string memory reason) {
            emit LogError(reason);
            return false;
    }
}

}
