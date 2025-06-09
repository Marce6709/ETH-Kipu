// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

//Elemento que define el contrato
contract MultiAuction {
    struct Auction {
        address owner;
        uint256 endTime;
        bool isActive;
        uint256 highestBid;
        address highestBidder;
        mapping(address => uint256) bids;
        mapping(address => uint256) amountBids;
        address[] bidders;
    }

    uint256 public auctionCount;
    mapping(uint256 => Auction) private auctions;

    event NewAuction(uint256 indexed auctionId, address indexed owner, uint256 endTime);
    event NewBid(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address winner, uint256 amount);

    modifier onlyOwner(uint256 _auctionId) {
        require(msg.sender == auctions[_auctionId].owner, "Solo el propietario puede ejecutar esta funcion");
        _;
    }

    modifier auctionActive(uint256 _auctionId) {
        require(auctions[_auctionId].isActive, "La subasta no esta activa");
        _;
    }

    modifier auctionEnded(uint256 _auctionId) {
        require(!auctions[_auctionId].isActive, "La subasta no termina aun");
        _;
    }

    function createAuction(uint256 _durationMinutes) external returns (uint256) {
        auctionCount++;
        Auction storage a = auctions[auctionCount];
        a.owner = msg.sender;
        a.endTime = block.timestamp + (_durationMinutes * 1 minutes);
        a.isActive = true;

        emit NewAuction(auctionCount, msg.sender, a.endTime);
        return auctionCount;
    }

    function placeBid(uint256 _auctionId) external payable auctionActive(_auctionId) {
        Auction storage a = auctions[_auctionId];
        require(block.timestamp < a.endTime, "La subasta ha terminado");
        require(msg.value > a.highestBid * 105 / 100, "La oferta debe ser al menos un 5% mayor");

        if (a.bids[msg.sender] == 0) {
            a.bidders.push(msg.sender);
        }

        a.highestBidder = msg.sender;
        a.highestBid = msg.value;
        a.bids[msg.sender] = msg.value;
        a.amountBids[msg.sender] += msg.value;

        if (a.endTime - block.timestamp <= 10 minutes) {
            a.endTime = block.timestamp + 10 minutes;
        }

        emit NewBid(_auctionId, msg.sender, msg.value);
    }

    function endAuction(uint256 _auctionId) external onlyOwner(_auctionId) auctionActive(_auctionId) {
        Auction storage a = auctions[_auctionId];
        a.isActive = false;
        sendDeposits(_auctionId);
        emit AuctionEnded(_auctionId, a.highestBidder, a.highestBid);
    }

    function withdraw(uint256 _auctionId) external auctionActive(_auctionId) {
        Auction storage a = auctions[_auctionId];
        uint256 withdrawValue = a.amountBids[msg.sender] - a.bids[msg.sender];
        require(withdrawValue > 0, "No hay fondos disponibles para retirar");
        a.amountBids[msg.sender] = a.bids[msg.sender];
        payable(msg.sender).transfer(withdrawValue);
    }

    function sendDeposits(uint256 _auctionId) internal auctionEnded(_auctionId) {
        Auction storage a = auctions[_auctionId];
        uint256 len = a.bidders.length;
        for (uint256 i = 0; i < len; i++) {
            address bidder = a.bidders[i];
            uint256 amount = a.bids[bidder];
            if (amount > 0 && bidder != a.highestBidder) {
                a.bids[bidder] = 0;
                payable(bidder).transfer(amount * 98 / 100);
            }
        }
        payable(a.owner).transfer(address(this).balance);
    }

    function getOffers(uint256 _auctionId) external view returns (address[] memory, uint256[] memory) {
        Auction storage a = auctions[_auctionId];
        uint256 length = a.bidders.length;
        address[] memory bidderAddresses = new address[](length);
        uint256[] memory bidAmounts = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            bidderAddresses[i] = a.bidders[i];
            bidAmounts[i] = a.bids[a.bidders[i]];
        }

        return (bidderAddresses, bidAmounts);
    }

    function getWinner(uint256 _auctionId) external view auctionEnded(_auctionId) returns (address) {
        return auctions[_auctionId].highestBidder;
    }
}
