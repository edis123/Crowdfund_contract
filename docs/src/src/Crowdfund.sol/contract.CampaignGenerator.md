# CampaignGenerator
[Git Source](https://github.com/edis123/Crowdfund_contract/blob/f9cb3a7bcb6d6e87405113f7d82e3dc728cf457c/src\Crowdfund.sol)


## State Variables
### campaignList

```solidity
address[] public campaignList;
```


## Functions
### createCampaign

This function allows a new campaign to be created by ANYONE.
The details of the new campaign (name, goal amount, deadline and description) are provided as parameters.

*Requires that the current block timestamp is less than or equal to the campaign's deadline, which is set by adding a certain number of blocks to the current one.*


```solidity
function createCampaign(string memory name, uint256 goal, uint256 deadline, string memory description) public;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`name`|`string`|The name for the new campaign.|
|`goal`|`uint256`|The funding goal($$$) for the new campaign.|
|`deadline`|`uint256`|The number of blocks until the end of the campaign.|
|`description`|`string`|A short description for the new campaign.|


### getAllCampaigns


```solidity
function getAllCampaigns() public view returns (address[] memory);
```

## Events
### CampaignCreated

```solidity
event CampaignCreated(address payable owner, string _name);
```

