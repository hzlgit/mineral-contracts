// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./IERC20.sol";
import "./SafeERC20.sol";
import "./ReentrancyGuard.sol";
import "./Ownable.sol";

contract MNERSale is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public MNER;

    mapping(uint256 => mapping(address => uint256)) public userOrders;

    mapping(uint256 => uint256) public startTime;
    mapping(uint256 => uint256) public endTime;

    address public manager = 0x3862A837c0Fd3b9eEE18C8945335c98a4F27Fb87;

    address public treasuryWallet;

    mapping(uint256 => bool) public claimes;

    bytes32 public constant PERMIT_TYPEHASH =
        0xf9a20c82276f5c164d15d306ea40d25f5a3dd062f72c8a4242a88c8eba769ea2;

    constructor(
        address _MNER,
        address _treasuryWallet,
        uint256 _startTime,
        uint256 _endTime
    ) Ownable(msg.sender) {
        MNER = _MNER;
        treasuryWallet = _treasuryWallet;
        startTime[1] = _startTime;
        endTime[1] = _endTime;
    }

    function setTime(
        uint256 round,
        uint256 _startTime,
        uint256 _endTime
    ) external onlyOwner {
        startTime[round] = _startTime;
        endTime[round] = _endTime;
    }

    function updateManager(address _m) external onlyOwner {
        manager = _m;
        emit UpdateManager(manager, _m);
    }

    function buy(uint256 round, uint256 source) public payable nonReentrant {
        require(block.timestamp < endTime[round], "MNER Sale: Over");
        require(
            block.timestamp > startTime[round],
            "MNER Sale: Has not started"
        );
        userOrders[round][msg.sender] += msg.value;

        emit Purchase(msg.sender, msg.value, round, source, block.timestamp);
    }

    function userAmounts(uint256 round, address _user)
        public
        view
        returns (uint256)
    {
        return userOrders[round][_user];
    }

    function claim(
        uint256 claimId,
        uint256 round,
        address user,
        uint256 amount,
        uint256 refund,
        bytes memory signature
    ) external nonReentrant {
        require(user == msg.sender, "MNER Sale: sender not match");
        require(!claimes[claimId], "MNER Sale: had claimed");

        require(
            verifySign(claimId, round, user, amount, refund, signature),
            "Invalid signature"
        );

        claimes[claimId] = true;
        if (refund > 0) {
            payable(user).transfer(refund);
        }
        payable(treasuryWallet).transfer(userAmounts(round, user) - refund);

        IERC20(MNER).safeTransfer(user, amount);

        emit Claim(claimId, user, amount, refund, manager);
    }

    function verifySign(
        uint256 claimId,
        uint256 round,
        address account,
        uint256 amount,
        uint256 refund,
        bytes memory signature
    ) internal view returns (bool verifySuc) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        claimId,
                        round,
                        account,
                        amount,
                        refund
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

        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "ECDSA: invalid signature 's' value");
        require(uint8(v) == 27 || uint8(v) == 28, "ECDSA: invalid signature 'v' value");
        address recoveredAddress = ecrecover(digest, v, r, s);

        return recoveredAddress != address(0) && recoveredAddress == manager;
    }


    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    event Received(address, uint256);

    event Claim(
        uint256 indexed claimId,
        address account,
        uint256 amount,
        uint256 refund,
        address signer
    );
    event Purchase(
        address indexed user,
        uint256 round,
        uint256 source,
        uint256 amount,
        uint256 time
    );
    event UpdateManager(address preManager, address indexed newManager);
}
