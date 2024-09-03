# Campaign
[Git Source](https://github.com/edis123/Crowdfund_contract/blob/f9cb3a7bcb6d6e87405113f7d82e3dc728cf457c/src\Crowdfund.sol)

**Inherits:**
[ReentrancyGuard](/src\Crowdfund.sol\contract.ReentrancyGuard.md)


## State Variables
### milestones

```solidity
Milestones[] public milestones;
```


### milestoneApprovals

```solidity
mapping(uint256 => mapping(address => bool)) public milestoneApprovals;
```


### contributors

```solidity
mapping(address => mapping(address => uint256)) public contributors;
```


### milestoneModifiers

```solidity
mapping(uint256 => mapping(address => bool)) public milestoneModifiers;
```


### campaignApprovals

```solidity
mapping(address => mapping(address => bool)) public campaignApprovals;
```


### contributorList

```solidity
address[] contributorList;
```


### milestoneApproversList

```solidity
address[] milestoneApproversList;
```


### milestonesModifiersList

```solidity
address[] milestonesModifiersList;
```


### campaignApprovalsList

```solidity
address[] campaignApprovalsList;
```


### campaign

```solidity
CampaignInfo public campaign;
```


## Functions
### constructor


```solidity
constructor(string memory _name, uint256 _goal, uint256 _deadline, string memory _description, address payable _owner);
```

### createMilestone

This function allows to create a new milestone if they are active campaign owner.
The status of the milestone can be 'Active'.
Only the owner of the contract can call this function.

*Requires that the campaign status must be 'Active', and only then the owner can add a new milestone.*


```solidity
function createMilestone(string memory _description, uint256 _amount) public onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_description`|`string`|A short description for the milestone.|
|`_amount`|`uint256`|The amount associated with the milestone.|


### approveMilestone

This function allows a contributor to approve a milestone.
The milestone can be approved only once by a contributor.
Only valid contributors can call this function.

*Requires that the campaign status must be active and the specified milestone must be active as well.
Also, the number of approvals for a milestone has to exceed half of total contributors for it not to be approved successfully.*


```solidity
function approveMilestone(uint256 milestoneIndex) public;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`milestoneIndex`|`uint256`|The index of the milestone in the list of all milestones.|


### modifyMilestone

This function allows a contributor to modify an existing milestone if they have approved it.
The description and amount associated with that milestone can be updated if approved by more than half of contributors.
Only the owner of the contract or contributors who've already contributed can call this function.

*Requires that the campaign status must be active and the specified milestone must be active as well.
Also, the number of approvals for a milestone has to exceed 50% of total contributors for it to be changed successfully.*


```solidity
function modifyMilestone(uint256 milestoneIndex) public;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`milestoneIndex`|`uint256`|The index of the milestone in the list of all milestones.|


### changeMilestone

This function allows the owner of a campaign to modify an existing milestone.
The description and amount associated with that milestone can be updated if approved by more than half of contributors.
Only the owner of the contract can call this function.

*Requires that the campaign status must be active and the specified milestone must be active as well.
Also, the number of approvals for a milestone has to exceed 50% of total contributors for it to be changed successfully.*


```solidity
function changeMilestone(uint256 milestoneIndex, string memory _description, uint256 _amount)
    public
    payable
    noReentrancy
    onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`milestoneIndex`|`uint256`|The index of the milestone in the list of all milestones.|
|`_description`|`string`|New description for the milestone.|
|`_amount`|`uint256`|New amount associated with the milestone.|


### finalizeMilestone

This function allows the owner of a campaign to finalize a milestone.
The funds associated with that milestone are released if approved by more than half of contributors.
Only the owner of the contract can call this function.

*Requires that the campaign status must be active and the specified milestone must be active as well.
Also, the number of approvals for a milestone has to exceed 50% of total contributors for it to be finalized successfully.*


```solidity
function finalizeMilestone(uint256 milestoneIndex) public payable noReentrancy onlyOwner;
```

### cancelMilestone

This function allows the owner of a campaign to cancel a milestone.
The funds associated with that milestone are not released, and can be used for future milestones.
Only the owner of the contract can call this function.

*Requires that the campaign status must be active and the specified milestone must be active as well.
If the milestone is cancelled successfully, its associated funds will not be released.*


```solidity
function cancelMilestone(uint256 milestoneIndex) public onlyOwner;
```

### contributeToCampaign

This function allows contributors to contribute to a campaign.
The amount contributed will be added to the total contribution of the campaign.
If the goal is reached or exceeded before the deadline, the funds are released.
Only valid contributions can be made.

*Requires that the campaign status must be active, the deadline has not passed,
the contribution amount is a positive number.
Also checks if the total contribution does not exceed the goal. If it exceeds, excess funds are returned to the contributor.*


```solidity
function contributeToCampaign() public payable noReentrancy;
```

### refundContributors

Function to allocates a  refund for each contributor if campaign failed and deadline passed.
The refund is calculated based on the amount contributed by a user.

*Requires that the campaign status has been set as 'Fail'. Contributor must have made a valid contribution.*


```solidity
function refundContributors() public noReentrancy;
```

### finalizeCampaign

Function to finalize a campaign and sets the status Success or Fail.
The funds associated with successful milestones are released to the owner, while failed campaigns return all funding to contributors.
Only the owner of the contract can call this function.


```solidity
function finalizeCampaign() public onlyOwner noReentrancy;
```

### suspendCampaign

records the number of suspensions and does not allow more that once( what would be the point otherwise).
Deactivates milestones that will be reactivated with the campaign.

*Only owner can call this.
Records the time of suspension for future audits and sets the status to "suspended".*


```solidity
function suspendCampaign() public onlyOwner;
```

### approveCampaign

This function allows a contributor to approve a campaign.
The campaign can be approved only once by a contributor.
Only valid contributors can call this function.

*Requires that the campaign status must be SUSPENDED.
Also, the number of approvals for a campaign has to exceed half of total contributors for it not to be approved successfully.*


```solidity
function approveCampaign() public;
```

### reactivateCampaign

This function is used to reactivate a previously suspended campaign WITHIN one week from suspension.
The function sets the status of the campaign back to 'Active' if it has been approved by more than half of contributors,
and NO more than one week have passed since its suspension.
Only the owner of the contract can call this function.

*Requires that the campaign status must be 'Suspended', and NO more than 7 days (approx. 1 week)
have passed after the campaign was suspended.
Also, it requires at least half of total contributors to approve for the campaign reactivation.*


```solidity
function reactivateCampaign() public onlyOwner;
```

### getCampaignDetails


```solidity
function getCampaignDetails() external view returns (CampaignInfo memory);
```

### getContributorInfo


```solidity
function getContributorInfo(address campaignId, address contributor) external view returns (uint256);
```

### getMilestoneStatus


```solidity
function getMilestoneStatus(uint256 milestoneIndex) external view returns (Milestones memory);
```

### getCampaignContributors


```solidity
function getCampaignContributors() external view returns (address[] memory);
```

### getTotalContributions


```solidity
function getTotalContributions() external view returns (uint256);
```

### onlyOwner


```solidity
modifier onlyOwner();
```

## Events
### ContributionMade

```solidity
event ContributionMade(uint256 amount, address contributor, address thisCampaign);
```

### MilestoneApproved

```solidity
event MilestoneApproved(uint256 milestoneIndex, string description);
```

### FundReleased

```solidity
event FundReleased(uint256 milestoneIndex, uint256 amount, address payable owner);
```

### RefundClaimed

```solidity
event RefundClaimed(address campaignId, address payable contributor);
```

### CampaignFinalized

```solidity
event CampaignFinalized(address campaignId, Status);
```

## Structs
### CampaignInfo

```solidity
struct CampaignInfo {
    string name;
    uint256 goal;
    uint256 deadline;
    uint256 suspendedOn;
    uint256 terminatedOn;
    string description;
    address id;
    address payable owner;
    uint256 totalContribution;
    uint256 totalContributors;
    uint256 approvedMilestones;
    uint256 approvalCount;
    uint256 suspensionCount;
    Status status;
}
```

### Milestones

```solidity
struct Milestones {
    string description;
    uint256 amount;
    Status status;
    uint256 approvalsCount;
    uint256 modifierCount;
}
```

## Enums
### Status

```solidity
enum Status {
    Active,
    Inactive,
    Success,
    Fail,
    Suspended
}
```

