// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./IERC20.sol";
import "./SafeERC20.sol";

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

interface IERC721 {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferFrom(address from, address to, uint256 tokenId) external;

    function approve(address to, uint256 tokenId) external;

    function getApproved(
        uint256 tokenId
    ) external view returns (address operator);

    function setApprovalForAll(address operator, bool _approved) external;

    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool);
}

contract Ownable {
    address internal owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract MineralGo is Ownable, IERC721Receiver {
    using SafeERC20 for IERC20;
    mapping(uint256 => uint256) public product;

    mapping(uint256 => uint256) public mproduct;

    mapping(uint256 => address) public Mineral;
    mapping(uint256 => address) public MNER;

    address public awardToken;
  

    uint256 orderId;
    uint256 morderId;

    mapping(uint256 => Order) public orders;
    mapping(uint256 => MOrder) public morders;

    address public manager = 0x3862A837c0Fd3b9eEE18C8945335c98a4F27Fb87;

    mapping(uint256 => bool) public claimes;

    bytes32 public constant PERMIT_TYPEHASH = 0xf9a20c82276f5c164d15d306ea40d25f5a3dd062f72c8a4242a88c8eba769ea2;

    event Claim(
        uint256 indexed claimId,
        uint256 claimType,
        address account,
        uint256 amount,
        uint256 deadline,
        address signer,
        uint256 time
    );
    event UpdateManager(address preManager, address indexed newManager);

    struct Order {
        address user;
        address token;
        uint256[] tokenIds;
        uint256 proId;
        uint256 unlockTime;
        bool redeem;
    }

    struct MOrder {
        address user;
        address token;
        uint256 amount;
        uint256 proId;
        uint256 unlockTime;
        bool redeem;
    }

    constructor() {
        product[0] = 1 * 86400;
        product[1] = 2 * 86400;
        product[2] = 3 * 86400;

        mproduct[0] = 1 * 86400;
        mproduct[1] = 2 * 86400;
        mproduct[2] = 3 * 86400;
    }

    function setMineralToken(uint256 tokenType, address _token) external onlyOwner {
      
        Mineral[tokenType] = _token;
    }
    function setMNERToken(uint256 tokenType, address _token) external onlyOwner {
      
        MNER[tokenType] = _token;
    }
    function setAwardToken(address _token) external onlyOwner {
        awardToken = _token;
    }
    function setMProduct(uint id, uint _times) external onlyOwner {
        mproduct[id] = _times;
    }

    function setProduct(uint id, uint _times) external onlyOwner {
        product[id] = _times;
    }

    function updateManager(address _m) external onlyOwner {
        manager = _m;
        emit UpdateManager(manager, _m);
    }

    function stakeMNER(uint256 _amount, uint256 _id, uint256 _tokenType) payable public {
        require(mproduct[_id] != 0, "Mineral: Staking package is incorrect");
        require(MNER[_tokenType] != address(0), "Mineral: Unsupported token");

        _safeTransferFrom(MNER[_tokenType], msg.sender, address(this), _amount);

        morderId++;
        morders[morderId] = MOrder({
            user: msg.sender,
            amount: _amount,
            proId: _id,
            token: MNER[_tokenType],
            unlockTime: block.timestamp + mproduct[_id],
            redeem: false
        });

        emit StakeMNER(msg.sender, _id, mproduct[_id]/86400, morderId, _tokenType, _amount, block.timestamp);
    }

    function redeemMNER(uint _orderId) public {
        require(
            morders[_orderId].user == msg.sender,
            "Mineral: Order is incorrect"
        );
        require(
            morders[_orderId].redeem != true,
            "Mineral: Order has been redeemed"
        );

        require(
            block.timestamp > morders[_orderId].unlockTime,
            "Mineral: Order has not yet reached the redemption time"
        );

        morders[_orderId].redeem = true;
        IERC20(morders[_orderId].token).transfer(msg.sender, morders[_orderId].amount);

        emit RedeemMNER(msg.sender, _orderId, block.timestamp);
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) private {
        if (amount == 0) {
            return;
        }
        if (token == address(0)) {
            require(msg.value == amount);
        } else {
            IERC20(token).safeTransferFrom(from, to, amount);
        }
    }

    function stakeNft(uint256[] memory _tokenIds, uint256 _id, uint256 _tokenType) public {
        require(product[_id] != 0, "Mineral: Staking package is incorrect");
        require(Mineral[_tokenType] != address(0), "Mineral: Unsupported token");
        require(
            IERC721(Mineral[_tokenType]).isApprovedForAll(msg.sender, address(this)),
            "Mineral: The token is not authorized"
        );

        for (uint i = 0; i < _tokenIds.length; i++) {
            require(
                IERC721(Mineral[_tokenType]).ownerOf(_tokenIds[i]) == msg.sender,
                "Mineral: You are not the owner of the token"
            );
            IERC721(Mineral[_tokenType]).safeTransferFrom(
                msg.sender,
                address(this),
                _tokenIds[i]
            );
        }
        orderId++;
        orders[orderId] = Order({
            user: msg.sender,
            tokenIds: _tokenIds,
            token:Mineral[_tokenType],
            proId: _id,
            unlockTime: block.timestamp + product[_id],
            redeem: false
        });

        emit Stake(msg.sender, _id, product[_id] / 86400, orderId, _tokenType, _tokenIds, block.timestamp);
    }

    function redeemNft(uint _orderId) public {
        require(
            orders[_orderId].user == msg.sender,
            "Mineral: Order is incorrect"
        );

        require(
            orders[_orderId].redeem != true,
            "Mineral: Order has been redeemed"
        );

        require(
            block.timestamp > orders[_orderId].unlockTime,
            "Mineral: Order has not yet reached the redemption time"
        );

        orders[_orderId].redeem = true;

        for (uint i = 0; i < orders[_orderId].tokenIds.length; i++) {
            IERC721(orders[_orderId].token).safeTransferFrom(
                address(this),
                msg.sender,
                orders[_orderId].tokenIds[i]
            );
        }

        emit Redeem(msg.sender, _orderId, block.timestamp);
    }

    function claim(
        uint256 claimId,
        uint256 claimType,
        address user,
        uint256 amount,
        uint256 deadline,
        bytes memory signature
    ) external {
        require(claimType==0 || claimType==1, "Mineral: Unsupported claimType");
        require(block.timestamp <= deadline, "Mineral: deadline");
        require(user == msg.sender, "Mineral: sender not match");
        require(!claimes[claimId], "Mineral: had claimed");

        require(
            verifySign(claimId, claimType,user, amount, deadline, signature),
            "Invalid signature"
        );

        claimes[claimId] = true;

        if(claimType == 0) {
            IERC20(awardToken).transfer(user, amount);
        } else {
            payable(user).transfer(amount);
        }

        emit Claim(claimId, claimType, user, amount, deadline, manager, block.timestamp);
    }

    function verifySign(
        uint256 claimId,
        uint256 claimType,
        address account,
        uint256 amount,
        uint256 deadline,
        bytes memory signature
    ) internal view returns (bool verifySuc) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        claimId,
                        claimType,
                        account,
                        amount,
                        deadline
                    )
                )
            )
        );

        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := and(mload(add(signature, 65)), 255)
        }

        address recoveredAddress = ecrecover(digest, v, r, s);

        return recoveredAddress != address(0) && recoveredAddress == manager;
    }

    function withdrawTokensSelf(address token, address to) external onlyOwner {
        if (token == address(0)) {
            payable(to).transfer(address(this).balance);
        } else {
            uint256 bal = IERC20(token).balanceOf(address(this));
            IERC20(token).transfer(to, bal);
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    event Received(address, uint);
    event Stake(
        address indexed user,
        uint256 id,
        uint256 _days,
        uint256 orderId,
        uint256 tokenType,
        uint256[] tokenIds,
        uint256 time
    );
    event Redeem(address indexed user, uint256 orderId, uint256 time);
    event StakeMNER(
        address indexed user,
        uint256 id,
        uint256 _days,
        uint256 orderId,
        uint256 tokenType,
        uint256 amount,
        uint256 time
    );
    event RedeemMNER(address indexed user, uint256 orderId, uint256 time);
}
