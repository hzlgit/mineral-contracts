// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./Address.sol";
import "./IERC20.sol";
import "./IERC721.sol";
import "./SafeERC20.sol";
import "./ReentrancyGuard.sol";
import "./Ownable.sol";
import "./IERC721Receiver.sol";

contract MineralGo is Ownable, ReentrancyGuard, IERC721Receiver {
    using SafeERC20 for IERC20;
    using Address for address;
    mapping(uint256 => uint256) public product;

    mapping(uint256 => uint256) public mproduct;

    mapping(uint256 => address) public Mineral;
    mapping(uint256 => address) public MNER;

    address public awardToken;

    uint256 orderId;
    uint256 morderId;

    uint256 public totalStakedMNER;
    mapping(uint256 => Order) public orders;
    mapping(uint256 => MOrder) public morders;

    address public manager = 0x3862A837c0Fd3b9eEE18C8945335c98a4F27Fb87;

    mapping(uint256 => bool) public claimes;

    bytes32 public constant PERMIT_TYPEHASH =
        0xf9a20c82276f5c164d15d306ea40d25f5a3dd062f72c8a4242a88c8eba769ea2;

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

    constructor(address _mineralToken, address _mnerToken) Ownable(msg.sender) {
        require(
            _mineralToken != address(0),
            "MNER Sale: address zero is not a valid Mineral"
        );
        require(
            _mnerToken != address(0),
            "MNER Sale: address zero is not a valid MNER"
        );
        product[0] = 30 * 86400;
        product[1] = 180 * 86400;
        product[2] = 360 * 86400;

        mproduct[0] = 30 * 86400;
        mproduct[1] = 180 * 86400;
        mproduct[2] = 360 * 86400;

        Mineral[0] = _mineralToken;
        MNER[0] = _mnerToken;
        awardToken = _mnerToken;
    }

    function awardTokenBalance() public view returns (uint256) {
        return IERC20(awardToken).balanceOf(address(this)) - totalStakedMNER;
    }

    function stakeMNER(
        uint256 _amount,
        uint256 _id,
        uint256 _tokenType
    ) public nonReentrant {
        require(mproduct[_id] != 0, "Mineral: Staking package is incorrect");
        require(MNER[_tokenType] != address(0), "Mineral: Unsupported token");

        morderId++;
        morders[morderId] = MOrder({
            user: msg.sender,
            amount: _amount,
            proId: _id,
            token: MNER[_tokenType],
            unlockTime: block.timestamp + mproduct[_id],
            redeem: false
        });
        if (MNER[_tokenType] == awardToken) {
            totalStakedMNER += _amount;
        }

        IERC20(MNER[_tokenType]).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        emit StakeMNER(
            msg.sender,
            _id,
            mproduct[_id] / 86400,
            morderId,
            _tokenType,
            _amount,
            block.timestamp
        );
    }

    function redeemMNER(uint256 _orderId) public nonReentrant {
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

        if (morders[_orderId].token == awardToken) {
            totalStakedMNER -= morders[_orderId].amount;
        }

        IERC20(morders[_orderId].token).safeTransfer(
            msg.sender,
            morders[_orderId].amount
        );

        emit RedeemMNER(msg.sender, _orderId, block.timestamp);
    }

    function stakeNft(
        uint256[] memory _tokenIds,
        uint256 _id,
        uint256 _tokenType
    ) public nonReentrant {
        require(product[_id] != 0, "Mineral: Staking package is incorrect");
        require(
            Mineral[_tokenType] != address(0),
            "Mineral: Unsupported token"
        );
        require(
            _checkOnERC721Received(msg.sender, msg.sender, _tokenIds[0], ""),
            "ERC721: transfer to non ERC721Receiver implementer"
        );

        for (uint256 i = 0; i < _tokenIds.length; i++) {
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
            token: Mineral[_tokenType],
            proId: _id,
            unlockTime: block.timestamp + product[_id],
            redeem: false
        });

        emit Stake(
            msg.sender,
            _id,
            product[_id] / 86400,
            orderId,
            _tokenType,
            _tokenIds,
            block.timestamp
        );
    }

    function redeemNft(uint256 _orderId) public nonReentrant {
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

        for (uint256 i = 0; i < orders[_orderId].tokenIds.length; i++) {
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
    ) external nonReentrant {
        require(
            claimType == 0 || claimType == 1,
            "Mineral: Unsupported claimType"
        );
        require(block.timestamp <= deadline, "Mineral: deadline");
        require(user == msg.sender, "Mineral: sender not match");
        require(!claimes[claimId], "Mineral: had claimed");
        require(
            verifySign(claimId, claimType, user, amount, deadline, signature),
            "Invalid signature"
        );

        claimes[claimId] = true;

        if (claimType == 0) {
            require(
                awardTokenBalance() > amount,
                "Mineral: Insufficient MNER balance"
            );
            IERC20(awardToken).safeTransfer(user, amount);
        } else {
            payable(user).transfer(amount);
        }

        emit Claim(
            claimId,
            claimType,
            user,
            amount,
            deadline,
            manager,
            block.timestamp
        );
    }

    function setMineralToken(uint256 tokenType, address _token)
        external
        onlyOwner
    {
        require(
            _token != address(0),
            "MNER Sale: address zero is not a valid token address"
        );
        require(
            Mineral[tokenType] == address(0),
            "Mineral: Cannot change token address"
        );
        Mineral[tokenType] = _token;
        emit UpdateMineralToken(tokenType, _token);
    }

    function setMNERToken(uint256 tokenType, address _token)
        external
        onlyOwner
    {
        require(
            _token != address(0),
            "MNER Sale: address zero is not a valid token address"
        );
        require(
            MNER[tokenType] == address(0),
            "Mineral: Cannot change token address"
        );
        MNER[tokenType] = _token;
        emit UpdateMNERToken(tokenType, _token);
    }

    function setMProduct(uint256 id, uint256 _times) external onlyOwner {
        mproduct[id] = _times;
        emit UpdateMNERProduct(id, _times);
    }

    function setProduct(uint256 id, uint256 _times) external onlyOwner {
        product[id] = _times;
        emit UpdateMineralProduct(id, _times);
    }

    function updateManager(address _m) external onlyOwner {
        require(
            _m != address(0),
            "MNER Sale: address zero is not a valid manager"
        );
        manager = _m;
        emit UpdateManager(manager, _m);
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

        require(
            uint256(s) <=
                0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0,
            "ECDSA: invalid signature 's' value"
        );
        require(
            uint8(v) == 27 || uint8(v) == 28,
            "ECDSA: invalid signature 'v' value"
        );

        address recoveredAddress = ecrecover(digest, v, r, s);

        return recoveredAddress != address(0) && recoveredAddress == manager;
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try
                IERC721Receiver(to).onERC721Received(
                    _msgSender(),
                    from,
                    tokenId,
                    data
                )
            returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert(
                        "ERC721: transfer to non ERC721Receiver implementer"
                    );
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
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

    event Received(address, uint256);
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
    event UpdateMineralToken(uint256 tokenType, address indexed token);
    event UpdateMNERToken(uint256 tokenType, address indexed token);
    event UpdateMineralProduct(uint256 id, uint256 indexed times);
    event UpdateMNERProduct(uint256 id, uint256 indexed times);
}
