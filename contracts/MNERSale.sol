// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./IERC20.sol";
import "./SafeERC20.sol";

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

contract MNERSale is Ownable {
    using SafeERC20 for IERC20;

    address public MNER;

    mapping(uint256 => mapping(address => uint256)) public userOrders;

    mapping(uint256 => uint256) public startTime;
    mapping(uint256 => uint256) public endTime;
    address public manager;

    address public treasuryWallet;

    mapping(uint256 => bool) public claimes;

    bytes32 public constant PERMIT_TYPEHASH =
        0xf9a20c82276f5c164d15d306ea40d25f5a3dd062f72c8a4242a88c8eba769ea2;

  

    constructor(
        address _MNER,
        uint256 _startTime,
        uint256 _endTime
    ) {
        MNER = _MNER;
        startTime[1] = _startTime;
        endTime[1] = _endTime;
    }

    function setTreasuryWallet(address _wallet) external onlyOwner {
        treasuryWallet = _wallet;
    }

    function setTime(
        uint256 round,
        uint256 _startTime,
        uint256 _endTime
    ) external onlyOwner {
        startTime[round] = _startTime;
        endTime[round] = _endTime;
    }

    function setToken(address _mner) external onlyOwner {
        MNER = _mner;
    }

    function updateManager(address _m) external onlyOwner {
        manager = _m;
        emit UpdateManager(manager, _m);
    }

    function buy(uint256 round) public payable {
        require(block.timestamp < endTime[round], "MNER Sale: Over");
        require(
            block.timestamp > startTime[round],
            "MNER Sale: Has not started"
        );
        userOrders[round][msg.sender] += msg.value;

        emit Purchase(msg.sender, msg.value, round, block.timestamp);
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
    ) external {
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

        IERC20(MNER).transfer(user, amount);

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
        uint256 amount,
        uint256 time
    );
    event UpdateManager(address preManager, address indexed newManager);
}
