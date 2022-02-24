// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Dai is ERC20 {
    constructor() ERC20('Mock DAI token', 'mDAI') {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
}

contract Glacier is ERC20 {
    address private owner;
    address private minter;
    uint private limit = 100000000 * 10 ** 18;

    constructor() ERC20('Glacier token', 'GLC') {
        owner = msg.sender;
        _mint(msg.sender, 2000000 * 10 ** 18);
    }

    function setMinterContract(address _minter) public{
        require(msg.sender == owner, 'You must be the owner to run this.');
        minter = _minter;
    }

    function setTranferLimit(uint _limit) public{
        require(msg.sender == owner, 'You must be the owner to run this.');
        limit = _limit;
    }

    function transferFrom(address sender, address recipient, uint amount) public override(ERC20) returns (bool) {
        require(amount <= limit, 'This transfer exceeds the allowed limit!');
        return super.transferFrom(sender, recipient, amount);
    }

    function transfer(address recipient, uint amount) public override(ERC20) returns (bool) {
        require(amount <= limit, 'This transfer exceeds the allowed limit!');
        return super.transfer(recipient, amount);
    }

    function mint(address to, uint _amount) public {
        require(msg.sender == minter || msg.sender == owner, 'Can only be used by Minter or owner.');
        _mint(to, _amount);
    }

    function burn(address from, uint _amount) public {
        require(msg.sender == minter || msg.sender == owner, 'Can only be used by Minter or owner.');
        _burn(from, _amount);
    }
}

contract GlaciersNFT is ERC721 {
    Dai public dai_token;
    Glacier public glacier_token;

    uint public glacierInterestRatePercent;
    address private owner;

    uint token_count;

    mapping(uint => NodeType) public node_type_list;
    mapping(uint => uint) public nft_node_types;
    mapping(uint => uint) public last_claim;
    mapping(uint => uint) public duration_left;
    mapping(uint => mapping(string => string)) public node_type_images;

    struct NodeType {
        uint multiplier;
        uint duration;
        uint dai_cost;
        uint glacier_cost;
    }

    constructor() ERC721("My NFT", "MNFT") {
        owner = msg.sender;
        glacierInterestRatePercent = 1 * 100;
        dai_token = Dai(0x0000000000000000000000000000000000000000);
        glacier_token = Glacier(0x0000000000000000000000000000000000000000);

        setNodeType(0, 1, 100, 1 ether, 1 ether);
        setNodeTypeImages(0,
            "http...",
            "http...",
            "http...",
            "http...",
            "http...");
    }

    function setNodeTypeImages(uint node_type_id,
        string memory almost_full,
        string memory half,
        string memory a_quarter,
        string memory almost_empty,
        string memory empty) public
    {
        node_type_images[node_type_id]["almost full"] = almost_full;
        node_type_images[node_type_id]["half"] = half;
        node_type_images[node_type_id]["a quarter"] = a_quarter;
        node_type_images[node_type_id]["almost empty"] = almost_empty;
        node_type_images[node_type_id]["empty"] = empty;
    }

    function tokenURI(uint token_id) public view virtual override returns (string memory) {
        require(_exists(token_id), "ERC721Metadata: URI query for nonexistent token");
        uint node_type_id = nft_node_types[token_id];
        NodeType memory node_type = node_type_list[node_type_id];
        uint total_duration = node_type.duration;
        uint current_duration_left = duration_left[token_id];
        uint duration_percentage = (current_duration_left * 100) / total_duration;
        if(duration_percentage > 75)
            return node_type_images[node_type_id]["almost full"];
        if(duration_percentage > 50)
            return node_type_images[node_type_id]["half"];
        if(duration_percentage > 25)
            return node_type_images[node_type_id]["a quarter"];
        if(duration_percentage > 1)
            return node_type_images[node_type_id]["almost empty"];
        return node_type_images[node_type_id]["empty"];
    }

    // PLAYER FUNCTIONS //

    function mintNode(uint node_type_id) public
    {
        _mint(msg.sender, token_count);

        NodeType memory node_type = node_type_list[node_type_id];
        nft_node_types[token_count] = node_type_id;

        dai_token.transferFrom(msg.sender, address(this), node_type.dai_cost);
        glacier_token.burn(msg.sender, node_type.glacier_cost);

        last_claim[token_count] = block.timestamp;
        duration_left[token_count] = node_type.duration;

        token_count += 1;
    }

    function claim(uint token_id) public
    {
        require(ownerOf(token_id) != address(0), "_to is address 0");
        require(msg.sender == ownerOf(token_id), 'Only user can widthraw its own funds.');
        require(block.timestamp - last_claim[token_id] > 0, 'Interest accumulated must be greater than zero.');

        uint amount = calculateClaim(token_id);

        uint time_elapsed = block.timestamp - last_claim[token_id];
        if(time_elapsed <= duration_left[token_id])
        {
            duration_left[token_id] -= time_elapsed;
        }else
        {
            duration_left[token_id] = 0;
        }

        glacier_token.mint(ownerOf(token_id), amount);
    }

    // HELPERS //

    function calculateClaim(uint token_id) public view returns(uint)
    {
        uint time_elapsed = block.timestamp - last_claim[token_id];
        if(time_elapsed > duration_left[token_id])
        {
            time_elapsed = duration_left[token_id];
        }
        uint multiplier = node_type_list[token_id].multiplier;
        return time_elapsed * (multiplier * glacierInterestRatePercent * 10 ** 18) / 100;
    }

    // OWNER ADMIN FUNCTIONS //

    function setNodeType(uint node_type_id, uint multiplier, uint duration, uint dai_cost, uint glacier_cost) public
    {
        node_type_list[node_type_id] = NodeType(multiplier, duration, dai_cost, glacier_cost);
    }

    function transferGlacier(address _address, uint amount) public
    {
        require(_address != address(0), "_address is address 0");
        require(msg.sender == owner, 'You must be the owner to run this.');
        glacier_token.transfer(_address, amount);
    }

    function transferDai(address _address, uint amount) public
    {
        require(_address != address(0), "_address is address 0");
        require(msg.sender == owner, 'You must be the owner to run this.');
        dai_token.transfer(_address, amount);
    }

    function changeInterestRate(uint _newRate) public
    {
        require(msg.sender == owner, 'You must be the owner to run this.');
        glacierInterestRatePercent = _newRate;
    }
}