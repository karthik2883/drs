pragma solidity 0.4.15;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/token/StandardToken.sol';

/**
* Health Decentralized Record Service (DRS)
* This contract enables creation of services and keys which can
* be managed, shared, traded, and sold using Health Cash (HLTH).
* 
* These keys enable gatekeeper services and 
* cryptographically secure data exchanges. 
*/

contract HealthDRS is Ownable {

    StandardToken public token;
    address public latestContract = address(this);
    uint8 public version = 1; 

    struct Service {
        string url;
        address owner;
    }

    struct Key {
        address owner;
        bool canShare;
        bool canTrade;
        bool canSell;
        bytes32 service;
    }

    struct SalesOffer {
        address buyer;
        uint price;
        bool canSell;
    }

    mapping (bytes32 => Service) public services;
    bytes32[] public serviceList;

    mapping(bytes32 => Key) keys;
    bytes32[] public keyList;

    mapping(bytes32 => address[]) public owners;
    mapping(bytes32 => bytes32) public keyData;        
    mapping(bytes32 => SalesOffer) public salesOffers;
    mapping(bytes32 => bytes32) public tradeOffers;    

    event ServiceCreated(address indexed _owner, bytes32 indexed _service);
    event KeyCreated(address indexed _owner, bytes32 indexed _key);
    event KeySold(bytes32 _key, address indexed _seller, address indexed _buyer, uint _price);
    event KeysTraded(bytes32 indexed _key1, bytes32 indexed _key2);
    event Access(address indexed _owner, bytes32 indexed _from, bytes32 indexed _to, uint _time, string _data);
    event Message(address indexed _owner, bytes32 indexed _from, bytes32 indexed _to, uint _time, string _category, string _data);    
    event Log(address indexed _owner, bytes32 indexed _from, uint _time, string _data);        

    modifier validKey(bytes32 key) {
      require(keys[key].owner != address(0));
      _;
    }

    modifier validService(bytes32 service) {
      require(services[service].owner != address(0));
      _;
    }

    modifier ownsKey(bytes32 key) {
        require(isKeyOwner(key, msg.sender));
        _;
    }
 
    modifier ownsService(bytes32 service) {
        require(isServiceOwner(service, msg.sender));
        _;
    }

    modifier canSell(bytes32 key) {
      require(keys[key].canSell);
      _;
    }

    modifier canTrade(bytes32 key) {
      require(keys[key].canTrade);
      _;
    }

    modifier canShare(bytes32 key) {
      require(keys[key].canShare);
      _;
    }

    function isKeyOwner(bytes32 key, address account) 
        public 
        constant
        validKey(key)
        returns (bool)
    {
        bool owns = false;
        if (keys[key].owner == account) {
            owns = true;
        }
        if (owns == false && keys[key].canShare) {
            for (uint i = 0; i < owners[key].length; i++) {
                if (owners[key][i] == account) {
                    owns = true;
                    break;
                }
           }
        }
        return owns;
    }

    function isServiceOwner(bytes32 service, address account) 
        public 
        constant
        validService(service)
        returns (bool)
    {
        bool owns = false;
        if (services[service].owner == account) {
            owns = true;
        }
        if (owns == false) {
            for (uint i = 0; i < owners[service].length; i++) {
                if (owners[service][i] == account) {
                    owns = true;
                    break;
                }
           }
        }
        return owns;
    }

    function getUrl(bytes32 service) 
        public 
        constant 
        validService(service) 
        returns (string) 
    {
       return services[service].url;
    }

    function getUrlFromKey(bytes32 key)
        public
        constant
        validKey(key)
        returns (string) 
    {
        return services[keys[key].service].url;
    }

    function updateUrl(bytes32 service, string url) 
        public
        ownsService(service)
    {
       services[service].url = url;
    }

    //user must authorize this contract to spend Health Cash (HLTH)
    function authorizedToSpend() public constant returns (uint) {
        return token.allowance(msg.sender, address(this)); 
    }

    //allow owner access to tokens erroneously transfered to this contract
    function recoverTokens(StandardToken _token, uint amount) public onlyOwner {
        _token.transfer(owner, amount);
    }
   
    function setHealthCashToken(StandardToken _token) public onlyOwner {
        token = _token;
    }

    function setLatestContract(address _contract) public onlyOwner {
        latestContract = _contract;
    }

   /**
   * Create Services & Keys
   * Keys can also be issued to accounts
   */
    function createService(string url) public {
        bytes32 id = keccak256(url);
        require(services[id].owner == address(0)); //prevent overwriting
        services[id].owner = msg.sender;
        services[id].url = url;
        serviceList.push(id);
        ServiceCreated(msg.sender, id);
    }

    function createKey(bytes32 service) 
        public
        ownsService(service)        
    {
        issueKey(service, msg.sender);
    }
    
    function issueKey(bytes32 service, address issueTo) 
        public
        ownsService(service)  
    {
        bytes32 id = keccak256(service,now,issueTo);
        require(keys[id].owner == address(0));
        keys[id].owner = issueTo;       
        keys[id].service = service;
        keyList.push(id);        
        KeyCreated(issueTo, id);        
    }        

   /**
   * Share Services and Keys
   * allow owners to authorize other accounts 
   * a service can disable sharing for thier keys. 
   * Can also unshare. 
   */
    function shareKey(bytes32 key, address account)
        public
        ownsKey(key)
        canShare(key)
    {
        if (isKeyOwner(key, account) == false) {
            owners[key].push(account);
        }
    }

    function shareService(bytes32 service, address account)
        public
        ownsService(service)
    {
        if (isServiceOwner(service, account) == false) {
            owners[service].push(account);
        }
    }

    function unshareKey(bytes32 key, address account)
        public
        ownsKey(key)
    {
        for (uint i = 0; i < owners[key].length; i++) { 
            if (owners[key][i] == account) {
                if (i != owners[key].length - 1) {
                    owners[key][i] = owners[key][owners[key].length - 1];
                }
                owners[key].length--;
                break;
            }
        }
    }

    function unshareService(bytes32 service, address account)
        public
        ownsService(service)
    {
        for (uint i = 0; i < owners[service].length; i++) { 
            if (owners[service][i] == account) {
                if (i != owners[service].length - 1) {
                    owners[service][i] = owners[service][owners[service].length - 1];
                }
                owners[service].length--;
                break;
            }
        }
    }

    /**
    * Sell Keys
    * Services have to authorize keys for sale. 
    * Key owners can disable key selling at time 
    * of sale to prevent re-selling. 
    */
    function createSalesOffer(bytes32 key, address buyer, uint price, bool _canSell)
        public
        ownsKey(key)
        canSell(key)
    {
        //cancell trade offer & create sales offer
        tradeOffers[key] = bytes32(0);
        salesOffers[key].buyer = buyer;
        salesOffers[key].price = price;
        salesOffers[key].canSell = _canSell;        
    }

    function cancelSalesOffer(bytes32 key)
        public
        ownsKey(key)
    {
        salesOffers[key].buyer = address(0);
        salesOffers[key].price = 0;
        salesOffers[key].canSell = false;
    }

    function purchaseKey(bytes32 key, uint value) 
        public
        canSell(key)                
    {

       //require explictit authority to spend tokens on the purchasers behalf
       require(value <= authorizedToSpend()); 
       require(salesOffers[key].buyer == msg.sender);
       require(salesOffers[key].price == value);       

       //price, in HLTH tokens, is paid to the key's primary owner
       assert(token.transferFrom(msg.sender, keys[key].owner, value));
       
       KeySold(key, keys[key].owner, msg.sender, value);
       keys[key].owner = msg.sender;
       //allows for non-resellable keys
       keys[key].canSell = salesOffers[key].canSell; 

    }

    /**
    * Trade keys
    * both keys have to be authorized
    * to trade by thier respective services. 
    */
    function tradeKey(bytes32 have, bytes32 want)
        public
        ownsKey(have)
        canTrade(have)        
        canTrade(want)        
    {
       if (tradeOffers[want] == have) {
           
           KeysTraded(want, have);
           tradeOffers[want] = ""; //remove the tradeOffer

           //complete the trade
           keys[have].owner = keys[want].owner;
           keys[want].owner = msg.sender;

        } else {
            //create a trade offer & cancel sales offer
            cancelSalesOffer(have);
            tradeOffers[have] = want;
        }
    }

    /**
    * Manage Keys
    * Service owner can set key permissions
    * disabling sharing, trading, or selling 
    * removes shared owners, active trade 
    * offers, and active sales offers respectively
    *
    * Should also be able to get a key and service,
    * get a count of keys and services, and get
    * a key and service key from the respective 
    * lists. 
    */
    //service owner can set permissions
    function setKeyPermissions(
        bytes32 key, 
        bool canShare_, 
        bool canTrade_, 
        bool canSell_)
        public
        validKey(key)
    {
        require(isServiceOwner(keys[key].service, msg.sender));

        keys[key].canShare = canShare_;
        if (canShare_ == false) {
            owners[key].length = 0;
        }

        keys[key].canTrade = canTrade_;
        if (canTrade_ == false) {
            tradeOffers[key] = "";
        }

        keys[key].canSell = canSell_;
        if (canSell_ == false) {                
            salesOffers[key].buyer = 0;
            salesOffers[key].price = 0;
        }            

    }

    function getServiceCount() public constant returns (uint) {
        return serviceList.length;
    }

    function getKeyCount() public constant returns (uint) {
        return keyList.length;
    }

    function getService(bytes32 service) 
        public
        constant
        validService(service)
        returns(string, address) 
    {
       return (services[service].url, services[service].owner);
    }

    function getKey(bytes32 key) 
        public
        constant
        validKey(key)
        returns(address, bool, bool, bool, bytes32) 
    {
       return (keys[key].owner, 
               keys[key].canShare, 
               keys[key].canTrade, 
               keys[key].canSell, 
               keys[key].service);
    }

    /**
    * Key Data 
    * A service can store public data for its keys.
    */
    function getKeyData(bytes32 key, bytes32 dataKey)
        public
        constant
        validKey(key) 
        returns (bytes32)
    {
        return keyData[keccak256(key,dataKey)];
    }

    function setKeyData(bytes32 service, bytes32 key, bytes32 dataKey, bytes32 dataValue)
        public
        ownsService(service)        
        validKey(key)
    {
        require(keys[key].service == service);
        keyData[keccak256(key,dataKey)] = dataValue;
    }

    /**
    * ecrecover passthrough
    */
    function recoverAddress(
        bytes32 msgHash, 
        uint8 v, 
        bytes32 r, 
        bytes32 s) 
        constant
        returns (address) 
    {
      return ecrecover(msgHash, v, r, s);
    }

    /**
    * Logging & Messaging
    * functions for creating an auditable record of activity. 
    * A service can log access from any of its keys. 
    */
    function logAccess(bytes32 service, bytes32 key, string data)
        public
        ownsService(service)
        validKey(key)        
    {
        require(keys[key].service == service);
        Access(msg.sender, service, key, now, data);
    }

    //services and keys can log messages to each other
    function message(bytes32 from, bytes32 to, string category, string data)
        public
    {
        bool ownsFrom = false;
        if (isKeyOwner(from, msg.sender) || isServiceOwner(from, msg.sender)) {
            ownsFrom = true;
        }
        require(ownsFrom);

        bool validTo = false;
        if (keys[to].owner != address(0) || services[to].owner != address(0)) {
            validTo = true;
        }
        require(validTo);

        Message(msg.sender, from, to, now, category, data);
    }

    //any key or service can log
    function log(bytes32 from, string data)
        public
    {
        bool ownsFrom = false;
        if (isKeyOwner(from, msg.sender) || isServiceOwner(from, msg.sender)) {
            ownsFrom = true;
        }
        require(ownsFrom);

        Log(msg.sender, from, now, data);
    }

}