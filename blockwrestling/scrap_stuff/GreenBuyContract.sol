pragma solidity ^0.4.21;

contract GreenBuyContract {

    uint public kWh;
    uint public kWhDecimal;

    address public clientAddress;
    address public producerContractAddress;

    bool public active;
    bool public payed;
    bool public validated;

    function GreenBuyContract (uint _kWh, uint _kWhDecimal, address _clientAddress, address _producerContractAddress) public {
        kWh = _kWh;
        kWhDecimal = _kWhDecimal;
        clientAddress = _clientAddress;
        producerContractAddress = _producerContractAddress;
        active = false;
        payed = false;
        validated = false;
    }

    function activate() public onlyBy(producerContractAddress) {
        active = true;
    }

    function validate() public {
        require(msg.sender==producerContractAddress);
        validated = true;

        if(payed){
            withdraw();
        }
    }

    function withdraw() {
        GreenSellContract sellContract = GreenSellContract(producerContractAddress);
        ERC20 token = ERC20(sellContract.tokenAddress());

        uint amount = sellContract.kWhTokenPrice() * kWh;

        if(token.transfer(sellContract.producerAddress(), amount)){
            payed = true;
        }

    }

    function hold() public isActive() {
        require(msg.sender==producerContractAddress);

        GreenSellContract sellContract = GreenSellContract(producerContractAddress);
        uint amount = sellContract.kWhTokenPrice() * kWh;

        ERC20 token = ERC20(sellContract.tokenAddress());

        if(token.transferFrom(clientAddress, address(this), amount)){
            payed = true;
        }
    }

    modifier onlyBy(address _account)
    {
        require(msg.sender == _account);
        _;
    }
    modifier isActive()
    {
        require(active);
        _;
    }
}

contract GreenSellContract {

    uint public kWhTokenPrice;
    //MAX 3 DECIMALS
    uint public kWhTokenPriceDecimalPart;

    uint public kWhTotal;
    //MAX 3 DECIMALS
    uint public kWhTotalDecimalPart;

    uint public kWhTotalAvailable;
    address public producerAddress;
    address public validatorAddress;

    address public tokenAddress;

    address[] public buyContracts;

    function GreenSellContract (uint _kWhTokenPrice, uint _kWhTokenPriceDecimalPart, uint _kwhTotal, uint _kWhTotalDecimalPart, address _producerAddress, address _validatorAddress, address _tokenAddress) public {
        kWhTokenPrice = _kWhTokenPrice;
        kWhTotal = _kwhTotal;
        kWhTokenPriceDecimalPart = _kWhTokenPriceDecimalPart;
        kWhTotalDecimalPart = _kWhTotalDecimalPart;
        kWhTotalAvailable = _kwhTotal;
        producerAddress = _producerAddress;
        validatorAddress = _validatorAddress;
        tokenAddress = _tokenAddress;
    }

    function getKWHPrice() public constant returns (uint) {
        return kWhTokenPrice;
    }

    function addBuyContract(address buyContractAddress) public {
        ERC20 token = ERC20(tokenAddress);

        GreenBuyContract buyContract = GreenBuyContract(buyContractAddress);

        require(token.allowance(buyContract.clientAddress(), buyContractAddress) >= (buyContract.kWh() * kWhTokenPrice) && kWhTotalAvailable >= buyContract.kWh() && buyContract.kWh() > 0);

        kWhTotalAvailable -= buyContract.kWh();

        buyContracts.push(buyContract);

        buyContract.activate();
        buyContract.hold();
    }

    function validateContract(address buyContractAddress){
        require(msg.sender==validatorAddress);

        GreenBuyContract buyContract = GreenBuyContract(buyContractAddress);
        buyContract.validate();
    }
}

contract ERC20 {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}
