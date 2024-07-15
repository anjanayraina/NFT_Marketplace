// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.13;

import "openzeppelin/contracts/access/Ownable.sol";
import "openzeppelin/contracts/security/ReentrancyGuard.sol";
import "openzeppelin/contracts/token/ERC721/ERC721.sol";
import "openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin/contracts/utils/Counters.sol";
import "openzeppelin/contracts/utils/Strings.sol";

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

contract KenduChad is Ownable, ERC721Enumerable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using Strings for uint256;

    // You can use this hash to verify the image file containing all the kenduChads
    string public constant imageHash =
        "122dab9670c21ad538dafdbb87191c4d7114c389af616c42c545123123asd231";

    IERC20 public token_contract_addr =
        IERC20(0xc99bb5E1d9C3C4B0D4D2Da86296E73C2097c6Df2); // @audit GO make it constant 

    address public feeRecipient = 0xeC65818Ff0F8b071e587A0bBDBecC94DE739B6Ec; // Set the recipient address for the 10% fee
    uint8 public feePercentage = 10; // @audit GO make it constant 

    constructor() ERC721("KenduChad", "KenduChad") {}

    bool public isSaleOn = false;
    bool public saleHasBeenStarted = false;

    uint256 public constant MAX_MINTABLE_AT_ONCE = 4; // max 4 mint at once

    uint256[10] private _availableTokens;
    uint256 private _numAvailableTokens = 10;
    uint256 private _numFreeRollsGiven = 0;

    mapping(address => uint256) public freeRollkenduChads;

    uint256 private _lastTokenIdMintedInInitialSet = 10;

    function numTotalkenduChads() public view virtual returns (uint256) {
        return 10; // @audit High in the docs its written that 10k nft will be minted whereeas in the code its only 10 
    }

    function freeRollMint() public nonReentrant {
        uint256 toMint = freeRollkenduChads[msg.sender];
        freeRollkenduChads[msg.sender] = 0;
        uint256 remaining = numTotalkenduChads() - totalSupply();
        if (toMint > remaining) {
            toMint = remaining;
        }
        _mint(toMint);
    }

    function getNumFreeRollkenduChads(
        address owner
    ) public view returns (uint256) {
        return freeRollkenduChads[owner];
    }

    function mint(uint256 _numToMint) public nonReentrant {
        require(isSaleOn, "Sale hasn't started.");
        uint256 totalSupply = totalSupply();
        require(
            totalSupply + _numToMint <= numTotalkenduChads(),
            "There aren't this many kenduChads left."
        );
        uint256 costForMintingkenduChads = getCostForMintingkenduChads(
            _numToMint
        );
        uint256 feeRecipientAmount = _calculateFee(costForMintingkenduChads);

        // Check allowance
        // @audit LR these checks are not needed as the transfer will fail if these checks are not met 
        uint256 allowance = token_contract_addr.allowance(
            msg.sender,
            address(this)
        );
        require(allowance >= costForMintingkenduChads, "Allowance too low");

        // Check balance
        uint256 balance = token_contract_addr.balanceOf(msg.sender);
        require(
            balance >= costForMintingkenduChads,
            "Insufficient token balance"
        );

        // Transfer the cost to this contract
        require(
            token_contract_addr.transferFrom(
                msg.sender,
                address(this),
                costForMintingkenduChads
            ),
            "Token transfer failed"
        ); // @audit LR consider using safeTransferFrom 

        // Transfer 10% to the fee recipient from contract
        require(
            token_contract_addr.transfer(feeRecipient, feeRecipientAmount),
            "Fee transfer failed"
        );

        // Proceed with minting the kenduChads
        _mint(_numToMint);
    }

    // internal minting function
    function _mint(uint256 _numToMint) internal {
        require(
            _numToMint <= MAX_MINTABLE_AT_ONCE,
            "Minting too many at once."
        );

        uint256 updatedNumAvailableTokens = _numAvailableTokens;
        for (uint256 i = 0; i < _numToMint; i++) { // @audit GO can improve the for loop for gas optimizations 
            uint256 newTokenId = useRandomAvailableToken(_numToMint, i);
            _safeMint(msg.sender, newTokenId);
            updatedNumAvailableTokens--;
        }
        _numAvailableTokens = updatedNumAvailableTokens;
    }

    function useRandomAvailableToken(
        uint256 _numToFetch,
        uint256 _i
    ) internal returns (uint256) {
        uint256 randomNum = uint256(
            keccak256(
                abi.encode(
                    msg.sender,
                    tx.gasprice,
                    block.number,
                    block.timestamp,
                    blockhash(block.number - 1),
                    _numToFetch,
                    _i
                )
            )
        );
        uint256 randomIndex = randomNum % _numAvailableTokens;
        return useAvailableTokenAtIndex(randomIndex);
    }

    function useAvailableTokenAtIndex(
        uint256 indexToUse
    ) internal returns (uint256) {
        uint256 valAtIndex = _availableTokens[indexToUse];
        uint256 result;
        if (valAtIndex == 0) {
            // This means the index itself is still an available token
            result = indexToUse;
        } else {
            // This means the index itself is not an available token, but the val at that index is.
            result = valAtIndex;
        }

        uint256 lastIndex = _numAvailableTokens - 1;
        if (indexToUse != lastIndex) {
            // Replace the value at indexToUse, now that it's been used.
            // Replace it with the data from the last index in the array, since we are going to decrease the array size afterwards.
            uint256 lastValInArray = _availableTokens[lastIndex];
            if (lastValInArray == 0) {
                // This means the index itself is still an available token
                _availableTokens[indexToUse] = lastIndex;
            } else {
                // This means the index itself is not an available token, but the val at that index is.
                _availableTokens[indexToUse] = lastValInArray;
            }
        }

        _numAvailableTokens--;
        return result;
    }

    function _calculateFee(
        uint256 costForMintingkenduChads
    ) internal view returns (uint256) {
        uint256 feeRecipientAmount = (costForMintingkenduChads *
            feePercentage) / 100;
        return feeRecipientAmount;
    }

    function getCostForMintingkenduChads(
        uint256 _numToMint
    ) public view returns (uint256) {
        require(
            totalSupply() + _numToMint <= numTotalkenduChads(),
            "There aren't this many kenduChads left."
        );
        if (_numToMint >= 1 && _numToMint <= 10) {
            return 10_000 * _numToMint * 10 ** 18; // 10K Kendu Tokens equivalent in tokens per nft upto 10 nfts, adjust based on token decimals
        } else {
            revert("Unsupported mint amount");
        }
    }

    function getkenduChadsBelongingToOwner(
        address _owner
    ) external view returns (uint256[] memory) {
        uint256 numkenduChads = balanceOf(_owner);
        if (numkenduChads == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](numkenduChads);
            for (uint256 i = 0; i < numkenduChads; i++) {
                result[i] = tokenOfOwnerByIndex(_owner, i);
            }
            return result;
        }
    }

    /*
     * Dev stuff.
     */

    // metadata URI
    string private _baseTokenURI;

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function tokenURI(
        uint256 _tokenId
    ) public view override returns (string memory) {
        string memory base = _baseURI();
        string memory _tokenURI = string(
            abi.encodePacked(Strings.toString(_tokenId), ".png") 
        );

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }

        return string(abi.encodePacked(base, _tokenURI));
    }

    // contract metadata URI for opensea
    string public contractURI;

    /*
     * Owner stuff
     */

    function startSale() public onlyOwner {
        isSaleOn = true;
        saleHasBeenStarted = true;
    }

    function endSale() public onlyOwner {
        isSaleOn = false;
    }

    function updateFeeRecipient(address _feeRecipient) public onlyOwner {
        feeRecipient = _feeRecipient;
    }

    function giveFreeRoll(address receiver) public onlyOwner {
        // max number of free mints we can give to the community for promotions/marketing
        require(
            _numFreeRollsGiven < 200,
            "already given max number of free rolls"
        );
        uint256 freeRolls = freeRollkenduChads[receiver];
        freeRollkenduChads[receiver] = freeRolls + 1;
        _numFreeRollsGiven = _numFreeRollsGiven + 1;
    }

    // for handing out free rolls to v1 pmen owners
    // details on seeding info here: https://gist.github.com/cryptopmens/7f542feaee510e12464da3bb2a922713
    function seedFreeRolls(
        address[] memory tokenOwners,
        uint256[] memory numOfFreeRolls
    ) public onlyOwner {
        require(
            !saleHasBeenStarted,
            "cannot seed free rolls after sale has started"
        );
        require(
            tokenOwners.length == numOfFreeRolls.length,
            "tokenOwners does not match numOfFreeRolls length"
        );

        // light check to make sure the proper values are being passed
        require(numOfFreeRolls[0] <= 3, "cannot give more than 3 free rolls"); // @audit LR check is wrong , this should be in the loop checking for every ith index 

        for (uint256 i = 0; i < tokenOwners.length; i++) {
            freeRollkenduChads[tokenOwners[i]] = numOfFreeRolls[i];
        }
    }

    // for seeding the v2 contract with v1 state
    // details on seeding info here: https://gist.github.com/cryptopmens/7f542feaee510e12464da3bb2a922713
    function seedInitialContractState(
        address[] memory tokenOwners,
        uint256[] memory tokens
    ) public onlyOwner {
        require(
            !saleHasBeenStarted,
            "cannot initial pmen mint if sale has started"
        );
        require(
            tokenOwners.length == tokens.length,
            "tokenOwners does not match tokens length"
        );

        uint256 lastTokenIdMintedInInitialSetCopy = _lastTokenIdMintedInInitialSet;
        for (uint256 i = 0; i < tokenOwners.length; i++) {
            uint256 token = tokens[i];
            require(
                lastTokenIdMintedInInitialSetCopy > token,
                "initial pmen mints must be in decreasing order for our availableToken index to work"
            );
            lastTokenIdMintedInInitialSetCopy = token;

            useAvailableTokenAtIndex(token);
            _safeMint(tokenOwners[i], token);
        }
        _lastTokenIdMintedInInitialSet = lastTokenIdMintedInInitialSetCopy;
    }

    // URIs
    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function setContractURI(string memory _contractURI) external onlyOwner {
        contractURI = _contractURI;
    }

    function withdrawMoney() public payable onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
