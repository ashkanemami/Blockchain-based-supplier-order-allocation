pragma solidity ^0.8.0;

import "./FixidityLib.sol";

contract supplychain{
    address public shop;
    mapping (address => bool) suppliersList;
    address[3] suppliers;
    mapping (address => bool) customersLists;
    uint8 numSuppliers = 1;
    uint8 numCustomers = 1;
    int256 public Q;
    bool public order = false;

    struct weight{
        int256 w1;
        int256 w2;
        int256 w3;
    }

    weight w;

    struct supplierTerms{
        int256 P;
        int256 L;
        int256 R;
        int256 minQS;
        int256 maxQS;
    }

    struct shopTerms{
        int256 minQB;
        int256 c;
    }

    mapping (address => uint8) public supplierTermsLists;
    mapping (uint8 => supplierTerms) public supplierTermsIds;

    mapping (uint8 => shopTerms) public shopTermsIds;

    mapping (uint8 => int256) public minQ;

    mapping (uint8 => int256) public payPrice;

    int256 public payFee = 0;

    enum ShoppingPhases {Registration, Ordering, Allocation, Delivery ,Finished}
    ShoppingPhases currentPhase;

    event NewSupplyChainPhase(ShoppingPhases);

    mapping(address => uint) public balances;

    event Deposit(address sender, uint amount);
    event Withdrawal(address receiver, uint amount);
    event Transfer(address sender, address receiver, uint amount);

    constructor(int256 _w1, int256 _w2, int256 _w3){
        shop = msg.sender;
        w = weight(_w1,_w2,_w3);
        currentPhase = ShoppingPhases.Registration;
    }
    modifier onlyShop {
		require(msg.sender == shop, "Only shop may call this function.");
		_;
	}
    modifier duringRegistration {
		require(currentPhase == ShoppingPhases.Registration, "Regirtration phase is over.");
		_;
	}

	modifier duringOrdering {
		require(currentPhase == ShoppingPhases.Ordering, "Ordering phase is over.");
		_;
	}

	modifier duringAllocation {
		require(currentPhase == ShoppingPhases.Allocation, "Allocation phase is over.");
		_;
	}

	modifier duringDelivery {
		require(currentPhase == ShoppingPhases.Delivery, "Delivery phase is over.");
		_;
	}

	modifier duringFinished {
		require(currentPhase == ShoppingPhases.Finished, "Finished phase is over.");
		_;
	}

	modifier onlyCustormer {
		require(customersLists[msg.sender], "Only customer may call this function.");
		_;
	}

    modifier onlySupplier {
		require(suppliersList[msg.sender], "Only supplier may call this function.");
		_;
	}

    function addSupplierPublicKey(address supplierAddress) public onlyShop duringRegistration {
        suppliersList[supplierAddress] = true;
    }

    function customerRegister() public duringRegistration {
        customersLists[msg.sender] = true;
    }

    function endRegistration() public onlyShop duringRegistration {
        currentPhase = ShoppingPhases.Ordering;
        emit NewSupplyChainPhase(ShoppingPhases.Ordering);
    }

    function customerOrdering(int256 _Q) public {
        Q = FixidityLib.newFixed(_Q);
        order = true;
    }

    function supplierStatement(supplierTerms memory _supplierTerms) public onlySupplier duringOrdering {
        require(order == true, "State only after order of customer!");
        supplierTermsLists[msg.sender] = numSuppliers;
        suppliers[numSuppliers-1] = msg.sender;
        supplierTermsIds[numSuppliers] = _supplierTerms;
        suppliersList[msg.sender] = false;
        if(numSuppliers == 3){
            currentPhase = ShoppingPhases.Allocation;
            emit NewSupplyChainPhase(ShoppingPhases.Allocation);

        }else{
            numSuppliers++;
        }
    }

    function minQCalulation() public onlyShop duringAllocation {
        for(uint8 i=1; i<=3; i++){
            int256 _minQS = supplierTermsIds[i].minQS;
            int256 _minQB = shopTermsIds[i].minQB;
            int256 max = _minQS >= _minQB ? _minQS : _minQB;
            if(max <= FixidityLib.multiply(shopTermsIds[i].c,Q)){
                minQ[i] = max;
            }else{
                minQ[i] = FixidityLib.multiply(shopTermsIds[i].c,Q);
            }
        }
    }

    function shopStatement(shopTerms memory _shopTerms, address _supplierAddress) public onlyShop duringAllocation {
        require(order == true && numSuppliers > 0, "State only after order of custmoer!");
        shopTermsIds[supplierTermsLists[_supplierAddress]] = _shopTerms;
        if(numSuppliers == 1){
            numSuppliers--;
            minQCalulation();
        }else{
            numSuppliers--;
        }

    }

    function payPriceCal() public onlyShop duringAllocation {
        int256[3] memory sum;
        int256[3] memory S;
        int256[3] memory P = [supplierTermsIds[1].P,supplierTermsIds[2].P,supplierTermsIds[3].P];
        int256[3] memory L = [supplierTermsIds[1].L,supplierTermsIds[2].L,supplierTermsIds[3].L];
        int256[3] memory R = [supplierTermsIds[1].R,supplierTermsIds[2].R,supplierTermsIds[3].R];
        for(uint8 i=0; i<3; i++){
            P[i] = FixidityLib.divide(FixidityLib.fixed1(),P[i]);
            R[i] = FixidityLib.divide(FixidityLib.fixed1(),R[i]);
            L[i] = FixidityLib.divide(FixidityLib.fixed1(),L[i]);
        }
        sum[0] = FixidityLib.add(FixidityLib.add(P[0],P[1]), P[2]);
        sum[1] = FixidityLib.add(FixidityLib.add(L[0],L[1]), L[2]);
        sum[2] = FixidityLib.add(FixidityLib.add(R[0],R[1]), R[2]);
        for(uint8 j=0; j<3; j++){
            P[j] = FixidityLib.multiply(w.w1,FixidityLib.divide(P[j],sum[0]));
            L[j] = FixidityLib.multiply(w.w2,FixidityLib.divide(L[j],sum[1]));
            R[j] = FixidityLib.multiply(w.w3,FixidityLib.divide(R[j],sum[2]));
        }

        for(uint8 k=0; k<3; k++){
            S[k] = FixidityLib.add(FixidityLib.add(P[k],R[k]), L[k]);
        }
        int256 summ = FixidityLib.add(FixidityLib.add(S[0],S[1]), S[2]);
        int256[3] memory minq = [minQ[1],minQ[2],minQ[3]];
        int256 sigmaQ = FixidityLib.add(FixidityLib.add(minQ[1],minQ[2]), minQ[3]);
        int256 q = FixidityLib.subtract(Q, sigmaQ);
        for(uint8 l=0; l<3; l++){
            S[l] = FixidityLib.multiply(q,FixidityLib.divide(S[l],summ));
            S[l] = FixidityLib.add(minq[l],S[l]);
            S[l] = FixidityLib.multiply(S[l],supplierTermsIds[l+1].P);
            payPrice[l+1] = FixidityLib.fromFixed(S[l]);
            payFee = payFee + payPrice[l+1];
        }
    }

    function deposit() public onlyShop duringAllocation  payable {
        require(msg.value == uint256(payFee) , "Not equal");
        emit Deposit(msg.sender, msg.value);
        balances[msg.sender] += msg.value;
        currentPhase = ShoppingPhases.Delivery;
        emit NewSupplyChainPhase(ShoppingPhases.Delivery);
    }

    function transfer(address[3] memory receivers, uint[3] memory amount) public onlyShop duringDelivery {
        uint sum = 0;
        for (uint i=0; i<amount.length; i++) {
            sum = sum + amount[i];
        }
        require(balances[msg.sender] >= sum, "Insufficient funds");
        for (uint i=0; i<receivers.length; i++) {
            emit Transfer(msg.sender, receivers[i], amount[i]);
            balances[msg.sender] -= amount[i];
            balances[receivers[i]] += amount[i];
        }
    }

    function delivery() public onlyShop duringDelivery {
        transfer(suppliers, [uint256(payPrice[1]), uint256(payPrice[2]), uint256(payPrice[3])]);
        currentPhase = ShoppingPhases.Finished;
        emit NewSupplyChainPhase(ShoppingPhases.Finished);
    }

    function withdraw(uint amount) public duringFinished {
        require(balances[msg.sender] >= amount, "Insufficient funds");
        emit Withdrawal(msg.sender, amount);
        balances[msg.sender] -= amount;
    }
}
