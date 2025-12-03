// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol"; 
import {PriceConverter} from "./PriceConverter.sol";

error FundMe__NotOwner();

contract FundMe {
    using PriceConverter for uint256;

    // storage variables
    address[] private s_funders;
    mapping(address funder => uint256 amountFunded) private s_addressToAmountFunded;

    address private immutable i_owner;
    uint256 public constant MINIMUM_USD = 5e18;
    AggregatorV3Interface private s_priceFeed;

    constructor(address priceFeed) {
        i_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    function fund() public payable  {
        require(msg.value.getConversionRate(s_priceFeed) > MINIMUM_USD, "did not send enough ETH"); // 1e18 = 1 eth
        s_funders.push(msg.sender);
        s_addressToAmountFunded[msg.sender] += msg.value;
    }

    function getVersion() public view returns (uint256) {
        return s_priceFeed.version();
    }

    function cheaperWithdraw() public onlyOwner {
        uint256 fundersLength = s_funders.length;
        for (uint256 funderIndex = 0; funderIndex < fundersLength; funderIndex++) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        (bool callSuccess,) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call failed");
    }

    function withdraw() public onlyOwner {
        
        for (uint256 funderIndex = 0; funderIndex < s_funders.length; funderIndex++) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        
        // 3 different ways to send funds from the contract, transfer, send, call
        //payable(msg.sender) = payable address
        //1- payable(msg.sender).transfer(address(this).balance);
        // if fail revert the transaction
        //2- bool sendSuccess = payable(msg.sender).send(address(this).balance);
        //require(sendSuccess, "Send Failed");
        //3- lower level 
        (bool callSuccess,) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call failed");
    }
    
    modifier onlyOwner() {
        //require(msg.sender == i_owner, "Sender is not owner!"); this cost more gas
        if (msg.sender != i_owner) { revert FundMe__NotOwner(); }
        _;
    }

    receive() external payable {
        fund();
    }

    fallback() external payable { 
        fund();
     }

     /**    
      * View / Pure functions (Getters)
      */

     function getAddressToAmountFunded(address fundingAddress) external view returns (uint256) {
        return s_addressToAmountFunded[fundingAddress];
     }

     function getFunder(uint256 index) external view returns (address) {
        return s_funders[index];
     }

     function getOwner() external view returns (address) {
        return i_owner;
     }
}