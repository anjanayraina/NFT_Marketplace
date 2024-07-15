// SPDX-License-Identifier: MIT License
pragma solidity 0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

/**
 * @dev Contract module which provides access control
 *
 * the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * mapped to
 * `onlyOwner`
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// @audit Med centralization risk 
contract KenduChadMarketplace is ReentrancyGuard, Pausable, Ownable {
    IERC721Enumerable chadsContract; // instance of the KenduChads NFT contract

    address public platformFeeRecipient =
        0xeC65818Ff0F8b071e587A0bBDBecC94DE739B6Ec; // Set the recipient address for the 10% fee
    // @audit LR the documentation suggests 2.5% fee whereas in the code the fee is 5%  
    uint8 public platformFeePercentage = 5; // 5% fee
    uint8 public nftHoldersShareOnPlatformFee = 50; // 50% fee share to NFT holders

    struct Offer {
        bool isForSale;
        uint chadIndex; // chad id
        address seller;
        uint minValue; // in ether
        address onlySellTo;
    }

    struct Bid {
        bool hasBid; // @audit GO no need in keeping this variable in the struct as its not being used 
        uint chadIndex;
        address bidder;
        uint value;
    }

    // A record of chads that are offered for sale at a specific minimum value, and perhaps to a specific person
    mapping(uint => Offer) public chadsOfferedForSale;

    // A record of the highest chad bid
    mapping(uint => Bid) public chadBids;

    // A record of pending ETH withdrawls by address
    mapping(address => uint) public pendingWithdrawals;

    event ChadOffered(
        uint indexed chadIndex,
        uint minValue,
        address indexed toAddress
    );
    event ChadBidEntered(
        uint indexed chadIndex,
        uint value,
        address indexed fromAddress
    );
    event ChadBidWithdrawn(
        uint indexed chadIndex,
        uint value,
        address indexed fromAddress
    );
    event ChadBought(
        uint indexed chadIndex,
        uint value,
        address indexed fromAddress,
        address indexed toAddress
    );
    event ChadNoLongerForSale(uint indexed chadIndex);

    /* Initializes contract with an instance of KenduChads contract, and sets deployer as owner */
    constructor(address initialChadsAddress) {
        // this line does not store or use the result, it serves as a verification step to ensure that the initialChadsAddress is a valid contract that implements the IERC721 interface. If initialChadsAddress does not support IERC721, this call will revert and the constructor will fail.
        
        IERC721Enumerable(initialChadsAddress).balanceOf(address(this));
        chadsContract = IERC721Enumerable(initialChadsAddress);
    }

    function pause() public whenNotPaused onlyOwner {
        _pause();
    }

    function unpause() public whenPaused onlyOwner {
        _unpause();
    }

    /* Returns the KenduChads contract address currently being used */
    function chadsAddress() public view returns (address) {
        return address(chadsContract);
    }

    /* Allows the owner of the contract to set a new KenduChads contract address */
    function setChadsContract(address newChadsAddress) public onlyOwner {
        chadsContract = IERC721Enumerable(newChadsAddress);
    }

    /* Allows the owner of a KenduChads to stop offering it for sale */
    function chadNoLongerForSale(uint chadIndex) public nonReentrant {
        if (chadIndex >= 10000) revert("token index not valid"); // @audit GO consider using custom reverts for saving gas 
        if (chadsContract.ownerOf(chadIndex) != msg.sender)
            revert("you are not the owner of this token");
        chadsOfferedForSale[chadIndex] = Offer(
            false,
            chadIndex,
            msg.sender,
            0,
            address(0x0)
        ); //@audit GO much better if we just do chadsOfferedForSale[chadIndex].isForSale = falsel 
        emit ChadNoLongerForSale(chadIndex);
    }

    /* Allows a KenduChad owner to offer it for sale */
    function offerChadForSale(
        uint chadIndex,
        uint minSalePriceInWei
    ) public whenNotPaused nonReentrant {
        if (chadIndex >= 10000) revert("token index not valid");
        if (chadsContract.ownerOf(chadIndex) != msg.sender) // @audit LR best practice is creating a modifier for these checks 
            revert("you are not the owner of this token");
        chadsOfferedForSale[chadIndex] = Offer(
            true,
            chadIndex,
            msg.sender,
            minSalePriceInWei,
            address(0x0)
        );
        emit ChadOffered(chadIndex, minSalePriceInWei, address(0x0));
    }

    /* Allows a KenduChad owner to offer it for sale to a specific address */
    function offerChadForSaleToAddress(
        uint chadIndex,
        uint minSalePriceInWei,
        address toAddress
    ) public whenNotPaused nonReentrant {
        if (chadIndex >= 10000) revert();
        if (chadsContract.ownerOf(chadIndex) != msg.sender)
            revert("you are not the owner of this token");
        chadsOfferedForSale[chadIndex] = Offer(
            true,
            chadIndex,
            msg.sender,
            minSalePriceInWei,
            toAddress
        );
        emit ChadOffered(chadIndex, minSalePriceInWei, toAddress);
    }

    /* Allows users to buy a KenduChad offered for sale */
    function buyChad(uint chadIndex) public payable whenNotPaused nonReentrant {
        if (chadIndex >= 10000) revert("token index not valid");
        Offer memory offer = chadsOfferedForSale[chadIndex];
        if (!offer.isForSale) revert("chad is not for sale"); // chad not actually for sale
        if (offer.onlySellTo != address(0x0) && offer.onlySellTo != msg.sender)
            revert();
        // @audit LR make it msg.value >= offer.minValue 
        if (msg.value != offer.minValue) revert("not enough ether"); // Didn't send enough ETH
        address seller = offer.seller;
        if (seller == msg.sender) revert("seller == msg.sender");
        if (seller != chadsContract.ownerOf(chadIndex))
            revert("seller no longer owner of chad"); // Seller no longer owner of chad

        chadsOfferedForSale[chadIndex] = Offer(
            false,
            chadIndex,
            msg.sender,
            0,
            address(0x0)
        );
        chadsContract.safeTransferFrom(seller, msg.sender, chadIndex);

        uint256 fee = _calculateFee(msg.value);
        // distibute fee
        distibuteFee(fee);

        pendingWithdrawals[seller] += msg.value - fee;
        emit ChadBought(chadIndex, msg.value, seller, msg.sender);

        // Check for the case where there is a bid from the new owner and refund it.
        // Any other bid can stay in place.
        Bid memory bid = chadBids[chadIndex];
        if (bid.bidder == msg.sender) {
            // Kill bid and refund value
            pendingWithdrawals[msg.sender] += bid.value;
            chadBids[chadIndex] = Bid(false, chadIndex, address(0x0), 0);
        }
    }

    /* Allows users to retrieve ETH from sales */
    function withdraw() public nonReentrant {
        uint amount = pendingWithdrawals[msg.sender];
        // Remember to zero the pending refund before
        // sending to prevent re-entrancy attacks
        pendingWithdrawals[msg.sender] = 0;
        payable(msg.sender).transfer(amount); // @audit Med use call instead of transfer 
    }

    /* Allows users to enter bids for any KenduChad */
    function enterBidForChad(
        uint chadIndex
    ) public payable whenNotPaused nonReentrant {
        if (chadIndex >= 10000) revert("token index not valid");
        if (chadsContract.ownerOf(chadIndex) == msg.sender)
            revert("you already own this chad");
        if (msg.value == 0) revert("cannot enter bid of zero");
        Bid memory existing = chadBids[chadIndex];
        if (msg.value <= existing.value) revert("your bid is too low");
        if (existing.value > 0) {
            // Refund the failing bid
            pendingWithdrawals[existing.bidder] += existing.value;
        }
        chadBids[chadIndex] = Bid(true, chadIndex, msg.sender, msg.value);
        emit ChadBidEntered(chadIndex, msg.value, msg.sender);
    }

    /* Allows KenduChad owners to accept bids for their Chads */
    function acceptBidForChad(
        uint chadIndex,
        uint minPrice
    ) public whenNotPaused nonReentrant {
        if (chadIndex >= 10000) revert("token index not valid");
        if (chadsContract.ownerOf(chadIndex) != msg.sender)
            revert("you do not own this token");
        address seller = msg.sender;
        Bid memory bid = chadBids[chadIndex];
        if (bid.value == 0) revert("cannot enter bid of zero");
        if (bid.value < minPrice) revert("your bid is too low");

        address bidder = bid.bidder;
        if (seller == bidder) revert("you already own this token");
        chadsOfferedForSale[chadIndex] = Offer(
            false,
            chadIndex,
            bidder,
            0,
            address(0x0)
        );
        uint amount = bid.value;
        chadBids[chadIndex] = Bid(false, chadIndex, address(0x0), 0);
        chadsContract.safeTransferFrom(msg.sender, bidder, chadIndex);

        uint256 fee = _calculateFee(amount);
        // distibute fee
        distibuteFee(fee);

        pendingWithdrawals[seller] += amount - fee;
        emit ChadBought(chadIndex, bid.value, seller, bidder);
    }

    /* Allows bidders to withdraw their bids */
    // @audit-info can allow for a DOS on the bid where someone can bid and immediately unbid to keep the other bids from not gettig cleared 
    function withdrawBidForChad(uint chadIndex) public nonReentrant {
        if (chadIndex >= 10000) revert("token index not valid");
        Bid memory bid = chadBids[chadIndex];
        if (bid.bidder != msg.sender)
            revert("the bidder is not message sender");
        emit ChadBidWithdrawn(chadIndex, bid.value, msg.sender);
        uint amount = bid.value;
        chadBids[chadIndex] = Bid(false, chadIndex, address(0x0), 0);
        // Refund the bid money
        payable(msg.sender).transfer(amount);
    }

    function distibuteFee(uint256 fee) internal {
        uint256 feeToHolders = (fee * nftHoldersShareOnPlatformFee) / 100;
        uint256 feeToPlatform = fee - feeToHolders;

        // transfer to platform fee recipient
        payable(platformFeeRecipient).transfer(feeToPlatform); // @audit Med use call instead of transfer 

        // transfer to all the holders
        uint256 totalNFTs = chadsContract.totalSupply();
        uint256 amountPerHolder = feeToHolders / totalNFTs;

        if (amountPerHolder > 0) {
            for (uint256 index = 0; index < totalNFTs; index++) { // @audit GO the for loop can be optimized 
                address holder = chadsContract.ownerOf(
                    chadsContract.tokenByIndex(index)
                );
                pendingWithdrawals[holder] += amountPerHolder;
            }
        }
    }

    function updateFeeRecipient(address _feeRecipient) public onlyOwner {
        platformFeeRecipient = _feeRecipient;
    }

    function _calculateFee(uint256 amount) internal view returns (uint256) {
        uint256 fee = (amount * platformFeePercentage) / 100;
        return fee;
    }
}






https://skynet.certik.com/projects/unicly-cryptopunks-collection#code-security