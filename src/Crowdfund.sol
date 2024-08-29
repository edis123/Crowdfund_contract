pragma solidity >=0.7.0 <0.9.0;

// import "lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
///SAFE MATH

//IT PREVENTS REENTRANCY WHILE A FUNCTION IS EXECUTING BY LOCKING IT
//THE AMOUNT TRANSFERED CANNOT BE MODIFIED WHILE EXECUTING
contract ReentrancyGuard {
    bool private locked = false;

    modifier noReentrancy() {
        require(!locked, "No reentrancy");
        locked = true;
        _;
        locked = false;
    }
}

//CREATES CAMPAIGN AND ASSIGNS AN OWNER
//SEE A LIST OF CAMPAIGNS HERE
contract CampaignGenerator {
    address[] public campaignList;

    event CampaignCreated(address payable owner, string _name);

    /**
     * @notice This function allows a new campaign to be created by ANYONE.
     * The details of the new campaign (name, goal amount, deadline and description) are provided as parameters.
     * @dev Requires that the current block timestamp is less than or equal to the campaign's deadline, which is set by adding a certain number of blocks to the current one.
     * @param name The name for the new campaign.
     * @param goal The funding goal($$$) for the new campaign.
     * @param deadline The number of blocks until the end of the campaign.
     * @param description A short description for the new campaign.
     */
    function createCampaign(string memory name, uint256 goal, uint256 deadline, string memory description) public {
        uint256 currentTime = block.timestamp;
        uint256 currentDeadline = currentTime + deadline;
        address owner = msg.sender;
        address payable thisOwner = payable(owner);
        Campaign newCampaign = new Campaign(name, goal, currentDeadline, description, thisOwner);

        campaignList.push(address(newCampaign));
        emit CampaignCreated(thisOwner, name);
    }

    //DISPLAYS ALL CAMPAIGNS ADDRESSES
    function getAllCampaigns() public view returns (address[] memory) {
        return campaignList;
    }
}

// CAMPAIGN STRUCTURE
contract Campaign is ReentrancyGuard {
    using Math for uint256; //  HANDLING 256 INTEGERS MATH OPERATIONS

    enum Status {
        Active,
        Inactive,
        Success,
        Fail,
        Suspended
    } // USEFULL TO IDENTFY THE CAMPAIGN/ MILESTONE STATUS

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

    // MILESTONE STRUCTURE
    struct Milestones {
        string description;
        uint256 amount;
        Status status;
        uint256 approvalsCount;
        uint256 modifierCount;
    }

    Milestones[] public milestones; //LIST OF MILESTONES
    mapping(uint256 => mapping(address => bool)) public milestoneApprovals; // FROM MILESTONE INDEX TO ITS APPROVER AND APPROVAL VOTE
    mapping(address => mapping(address => uint256)) public contributors; //FROM CONTRIBUTORS TO CAMPAIGN CONTRIBUTED AND AMOUNT
    mapping(uint256 => mapping(address => bool)) public milestoneModifiers; // FROM CAMPAIGN TO MILESTONE TO MODIFIERS VOTE
    mapping(address => mapping(address => bool)) public campaignApprovals; // FROM CAMPAIGN TO CONTRIBUTOR AND APPROVAL VOTE
    //THE FOLLOWING LISTS ARE USEFUL FOR ITERATIONS THROUGH DATA
    address[] contributorList; //RECORD CONTRIBUTORS
    address[] milestoneApproversList; //RECORD MILESTONE APPROVERS
    address[] milestonesModifiersList; //RECORD MILESTONE MODIFIERS
    address[] campaignApprovalsList; //RECORD CAMPAIGN APPROVERS //THIS WILL NOT BE RESETED SINCE VOTING FOR THE CAMPAIGN WILL HAPPEN ONLY ONCE

    CampaignInfo public campaign; //MY CAMPAIGN

    constructor(
        string memory _name,
        uint256 _goal,
        uint256 _deadline,
        string memory _description,
        address payable _owner
    ) {
        campaign = CampaignInfo({
            name: _name,
            goal: _goal,
            deadline: _deadline,
            suspendedOn: 0,
            terminatedOn: 0,
            description: _description,
            id: address(this),
            owner: _owner,
            totalContribution: 0,
            totalContributors: 0,
            approvedMilestones: 0,
            approvalCount: 0,
            suspensionCount: 0,
            status: Status.Active
        });
    }

    //ALL THE EVENTS HERE //MORE CAN BE IMPLEMENTED
    event ContributionMade(uint256 amount, address contributor, address thisCampaign);
    event MilestoneApproved(uint256 milestoneIndex, string description);
    event FundReleased(uint256 milestoneIndex, uint256 amount, address payable owner);
    event RefundClaimed(address campaignId, address payable contributor);
    event CampaignFinalized(address campaignId, Status);

    // CREATES A NEW MILESTONE BY OWNER ONLY
    /**
     * @notice This function allows to create a new milestone if they are active campaign owner.
     * The status of the milestone can be 'Active'.
     * Only the owner of the contract can call this function.
     * @dev Requires that the campaign status must be 'Active', and only then the owner can add a new milestone.
     * @param _description A short description for the milestone.
     * @param _amount The amount associated with the milestone.
     */
    function createMilestone(string memory _description, uint256 _amount) public onlyOwner {
        require(campaign.status == Status.Active, "Campaign not active");
        require(_amount < campaign.goal && _amount > 0, "Milestone Unrealistic,$$$");
        Milestones memory newMilestone = Milestones({
            description: _description,
            amount: _amount,
            status: Status.Active,
            approvalsCount: 0,
            modifierCount: 0
        });

        milestones.push(newMilestone);
    }

    //VOTE
    // CONTRIBUTORS CAN APPROVE A MILESTONE ONLY ONCE IF MILESTONE NOT APPROVED
    /**
     * @notice This function allows a contributor to approve a milestone.
     * The milestone can be approved only once by a contributor.
     * Only valid contributors can call this function.
     * @dev Requires that the campaign status must be active and the specified milestone must be active as well.
     * Also, the number of approvals for a milestone has to exceed half of total contributors for it not to be approved successfully.
     * @param milestoneIndex The index of the milestone in the list of all milestones.
     */
    function approveMilestone(uint256 milestoneIndex) public {
        address approver_X = msg.sender;
        Milestones storage milestone = milestones[milestoneIndex];
        require(campaign.status == Status.Active, "Campaign Not Active");
        require(contributors[approver_X][campaign.id] > 0, "Not A Contributor");
        require(milestone.status == Status.Active, "Already Approved");
        require(!milestoneApprovals[milestoneIndex][approver_X], "Already An Approver"); // !!!! APPROVER
        milestoneApprovals[milestoneIndex][approver_X] = true; // STORED AS AN APPROVER FOR THIS MILESTONE
        milestoneApproversList.push(approver_X);
        milestone.approvalsCount++;
    }

    //VOTE
    /**
     * @notice This function allows a contributor to modify an existing milestone if they have approved it.
     * The description and amount associated with that milestone can be updated if approved by more than half of contributors.
     * Only the owner of the contract or contributors who've already contributed can call this function.
     * @dev Requires that the campaign status must be active and the specified milestone must be active as well.
     * Also, the number of approvals for a milestone has to exceed 50% of total contributors for it to be changed successfully.
     * @param milestoneIndex The index of the milestone in the list of all milestones.
     */
    function modifyMilestone(uint256 milestoneIndex) public {
        address modifier_X = msg.sender;
        Milestones storage milestone = milestones[milestoneIndex];
        require(campaign.status == Status.Active, "Campaign Not Active");
        require(contributors[modifier_X][campaign.id] > 0, "Not A Contributor");
        require(milestone.status == Status.Active, "Already Approved");
        require(!milestoneApprovals[milestoneIndex][modifier_X], "Already An Approver"); // !!!! CANT MODIFY IF APPROVED
        require(!milestoneModifiers[milestoneIndex][modifier_X], "Already A Modifier"); //VOTE ONLY ONCE
        milestoneModifiers[milestoneIndex][modifier_X] == true; // STORED AS AN APPROVER FOR THIS MILESTONE
        milestonesModifiersList.push(modifier_X);
        milestone.modifierCount++;
    }

    //MODIFY MILESTONES, FUNDS WILL BE REALEASED IF APPROVED
    /**
     * @notice This function allows the owner of a campaign to modify an existing milestone.
     * The description and amount associated with that milestone can be updated if approved by more than half of contributors.
     * Only the owner of the contract can call this function.
     * @dev Requires that the campaign status must be active and the specified milestone must be active as well.
     * Also, the number of approvals for a milestone has to exceed 50% of total contributors for it to be changed successfully.
     * @param milestoneIndex The index of the milestone in the list of all milestones.
     * @param _description New description for the milestone.
     * @param _amount New amount associated with the milestone.
     */
    function changeMilestone(uint256 milestoneIndex, string memory _description, uint256 _amount)
        public
        payable
        noReentrancy
        onlyOwner
    {
        Milestones storage milestone = milestones[milestoneIndex];
        require(milestone.status == Status.Active, "Not Active");
        require(milestone.modifierCount > campaign.totalContributors / 2, "Not Enough Approvers"); //CHECK IF VOTED FROM MORE THAN HALF CONTRIBUTORS
        require(_amount < campaign.goal && _amount > 0, "Milestone Unrealistic,$$$");
        milestone.amount = _amount; // NEW AMOUNT
        milestone.description = _description; // NEW DESCRIPTION
        for (uint256 i = 0; i < milestonesModifiersList.length; i++) {
            milestoneModifiers[milestoneIndex][milestonesModifiersList[i]] = false; //RESET THE VOTING
        }
        milestone.modifierCount = 0; //RESET COUNT
    }

    //FINALIZE MILESTONE AND RELEASE FUNDS
    //CHECK REQIREMENTS FOR FINALIZATION, EMIT EVENTS
    /**
     * @notice This function allows the owner of a campaign to finalize a milestone.
     * The funds associated with that milestone are released if approved by more than half of contributors.
     * Only the owner of the contract can call this function.
     * @dev Requires that the campaign status must be active and the specified milestone must be active as well.
     * Also, the number of approvals for a milestone has to exceed 50% of total contributors for it to be finalized successfully.
     */
    function finalizeMilestone(uint256 milestoneIndex) public payable noReentrancy onlyOwner {
        Milestones storage milestone = milestones[milestoneIndex];
        require(milestone.status == Status.Active, "Not Active");
        require(milestone.approvalsCount > campaign.totalContributors / 2, "Not Enough Approvers"); //CHECK IF APPROVED FROM MORE THAN HALF CONTRIBUTORS
        milestone.status = Status.Success;
        emit MilestoneApproved(milestoneIndex, milestone.description);
        uint256 amount = milestone.amount;
        milestone.amount = 0;
        campaign.approvedMilestones++;
        campaign.owner.transfer(amount); // REALEASE FUND FOR THIS MILESTONE
        emit FundReleased(milestoneIndex, amount, campaign.owner);
    }

    //CANCEL MILESTONE,FUNDS NOT RELEASED AND WILL BE USED FOR OTHER MILESTONES
    /**
     * @notice This function allows the owner of a campaign to cancel a milestone.
     * The funds associated with that milestone are not released, and can be used for future milestones.
     * Only the owner of the contract can call this function.
     * @dev Requires that the campaign status must be active and the specified milestone must be active as well.
     * If the milestone is cancelled successfully, its associated funds will not be released.
     */
    function cancelMilestone(uint256 milestoneIndex) public onlyOwner {
        Milestones storage milestone = milestones[milestoneIndex];
        require(campaign.status == Status.Active, "Campaign not active");
        require(milestone.status == Status.Active, "Not Active");
        milestone.status = Status.Inactive;
        milestone.amount = 0;
    }

    //LOCKED WHILE EXECUTING
    //CHECK IF CAMPAIGN IS ACTIVE, GOAL NOT REACHED, VALID CONTRIBUTION
    /**
     * @notice This function allows contributors to contribute to a campaign.
     * The amount contributed will be added to the total contribution of the campaign.
     * If the goal is reached or exceeded before the deadline, the funds are released.
     * Only valid contributions can be made.
     * @dev Requires that the campaign status must be active, the deadline has not passed,
     * the contribution amount is a positive number.
     * Also checks if the total contribution does not exceed the goal. If it exceeds, excess funds are returned to the contributor.
     */
    function contributeToCampaign() public payable noReentrancy {
        uint256 amount = msg.value;
        address contributor_X = msg.sender;
        require(campaign.status == Status.Active, "Not Active");
        require(campaign.deadline > block.timestamp, "Campaign Terminated");
        // require(campaign.goal > campaign.totalContribution, "Goal Reached");
        require(amount > 0, "Not A Valid Amount");
        // require(msg.sender != campaign.owner,"Owner Connot Contribute"); //OWNER CANNOT CONTRIBUTE
        // require(contributors[msg.sender][campaign.id]+amount<=campaign.goal,"Exceeds Goal"); //CHECK IF CONTRIBUTION IS LESS THAN GOAL

        if ((contributors[contributor_X][campaign.id] + amount) == amount) {
            //IF ALREADY A CONTRIBUTER HIS CONTRIBUTIONS > amount
            contributorList.push(contributor_X); // STORE ONLY IF NEW
            campaign.totalContributors++;
        }
        uint256 excess = 0;
        uint256 contribution = amount;
        //ADJUST CONTRIBUTION TO NOT EXCEED GOAL
        if (campaign.goal < campaign.totalContribution + contribution) {
            excess = (contribution + campaign.totalContribution) - campaign.goal;
            contribution -= excess;
        }

        campaign.totalContribution += contribution;
        contributors[contributor_X][campaign.id] += contribution; //STORE THE CONTRIBUTION FOR THAT CONTRIBUTOR

        //RETURN EXCESS
        if (excess > 0) {
            payable(contributor_X).transfer(excess);
        }
        emit ContributionMade(campaign.totalContribution, contributor_X, campaign.id);
    }

    // ALL CONTRIBUTORS GET REFUND HERE IF GOAL NOT ACHIEVED PAST DEADLINE
    /**
     * @notice Function to allocates a  refund for each contributor if campaign failed and deadline passed.
     * The refund is calculated based on the amount contributed by a user.
     * @dev Requires that the campaign status has been set as 'Fail'. Contributor must have made a valid contribution.
     */
    function refundContributors() public noReentrancy {
        require(campaign.status == Status.Fail, "Campaign Not Failed, No Refunds");

        //REFUND IN PERCENTAGE OF THE AVAILABLE FUNDS // MONEY SPENT IS LOST FOREVER
        uint256 remainingBalance = address(this).balance;

        for (uint256 i = 0; i < contributorList.length; i++) {
            address contributor_X = contributorList[i];
            uint256 amountContributed = contributors[contributor_X][campaign.id];

            //FORMULA: PERCENTAGE = CONTRIBUTION/TOTAL  * 100 ; REFUND= PERCENTAGE/100  *REMAINING FUNDS
            //MULTIPLICATION IS DONE FIRST TO MINIMIZE LOSS
            //uint256 refund = (amountContributed * remainingBalance) / campaign.totalContribution;
            // uint256 refund = amountContributed.mul(remainingBalance).div(campaign.totalContribution);
            uint256 refund = Math.mulDiv(amountContributed, remainingBalance, campaign.totalContribution); // (a*b)/c

            payable(contributor_X).transfer(refund); // REFUNDED
            emit RefundClaimed(campaign.id, payable(contributor_X));
            contributors[contributor_X][campaign.id] = 0; // NOT A CONTRIBUTOR ANYMORE
            campaign.totalContributors--;
        }
    }

    // FINALIZE CAMPAIGN, AFTER DEADLINE OWNER GETS EVERYTHING
    // BEFORE DEADLINE, CONTRIBUTORS GET 5% OF THEIR CONTRIBUTION FOR THAT CAMPAIGN(NOT REALISTIC)
    /**
     * @notice Function to finalize a campaign and sets the status Success or Fail.
     * The funds associated with successful milestones are released to the owner, while failed campaigns return all funding to contributors.
     * Only the owner of the contract can call this function.
     */
    function finalizeCampaign() public onlyOwner noReentrancy {
        // SET THE NEW STATUS SUCCESS OR FAIL AFTER CHECKING DEADLINE , MILESTONES AND STATUS
        campaign.status = (
            campaign.totalContribution >= campaign.goal && campaign.approvedMilestones == milestones.length
                && campaign.status == Status.Active
        ) ? Status.Success : Status.Fail;

        campaign.terminatedOn = block.timestamp; // RECORD TERMINATION DATE
        emit CampaignFinalized(campaign.id, campaign.status);

        if ( //BONUS TIME
        campaign.status == Status.Success && campaign.deadline > campaign.terminatedOn) {
            for (uint256 i = 0; i < contributorList.length; i++) {
                address contributor_X = contributorList[i];
                uint256 smallBonus = contributors[contributor_X][campaign.id] / 20; //5% bonus
                payable(contributor_X).transfer(smallBonus); // BONUS SENT TO CONTRIBUTORS
            }
        } else if (campaign.status == Status.Success && campaign.deadline <= block.timestamp) {
            campaign.owner.transfer(campaign.totalContribution); //OWNER GETS THE MONEY, BUT NOT REALISTIC
        } else if (campaign.status == Status.Fail) {
            // REFUNDS ARE ISSUED IN CASE OF FAIL
            refundContributors();
        }
    }

    // SUSPEND CAMPAIGN FOR A WEEK,ONLY ONCE AND NO EXTENSIONS
    /**
     * @notice records the number of suspensions and does not allow more that once( what would be the point otherwise).
     * Deactivates milestones that will be reactivated with the campaign.
     * @dev Only owner can call this.
     * Records the time of suspension for future audits and sets the status to "suspended".
     */
    function suspendCampaign() public onlyOwner {
        require(campaign.status == Status.Active, "Not Active"); //CHECK STATUS
        if (campaign.suspensionCount > 1) {
            finalizeCampaign(); // FINALIZED AS FAILED IF SUSPENDED MORE THAN ONCE
        } else {
            for (uint256 i = 0; i < milestones.length; i++) {
                //DEACTIVATE ACTIVE MILESTONES/ FUNDS ARE NOT TOUCHED
                if (milestones[i].status == Status.Active) {
                    milestones[i].status = Status.Inactive;
                }
                campaign.status = Status.Suspended;
                campaign.suspensionCount++; //COUNTS HOW MANY TIME IS SUSPNDED, IF > 1 => FAIL
                campaign.suspendedOn = block.timestamp;
            }
        }
    }

    //VOTE TO REACTIVATE CAMPAIGN
    /**
     * @notice This function allows a contributor to approve a campaign.
     * The campaign can be approved only once by a contributor.
     * Only valid contributors can call this function.
     * @dev Requires that the campaign status must be SUSPENDED.
     * Also, the number of approvals for a campaign has to exceed half of total contributors for it not to be approved successfully.
     */
    function approveCampaign() public {
        address approver_X = msg.sender;
        require(campaign.status == Status.Suspended, "Not Suspended Campaign");
        require(contributors[approver_X][campaign.id] > 0, "Not A Contributor");
        require(!campaignApprovals[approver_X][campaign.id], "Already Approved Campaign"); //VOTE ONLY ONCE
        campaignApprovals[approver_X][campaign.id] == true; // STORED AS AN APPROVER FOR THIS MILESTONE
        campaignApprovalsList.push(approver_X);
        campaign.approvalCount++;
    }

    //REACTIVATES CAMPAIGN FROM SUSPENSION
    /**
     * @notice This function is used to reactivate a previously suspended campaign WITHIN one week from suspension.
     * The function sets the status of the campaign back to 'Active' if it has been approved by more than half of contributors,
     *     and NO more than one week have passed since its suspension.
     * Only the owner of the contract can call this function.
     * @dev Requires that the campaign status must be 'Suspended', and NO more than 7 days (approx. 1 week)
     *     have passed after the campaign was suspended.
     *     Also, it requires at least half of total contributors to approve for the campaign reactivation.
     */
    function reactivateCampaign() public onlyOwner {
        require(campaign.status == Status.Suspended, "Campaign Not Suspended");
        require(campaign.approvalCount > campaign.totalContributors / 2, "Not Enough Approvals");
        uint256 rightNow = block.timestamp;
        if (campaign.suspendedOn + 10080 < rightNow) {
            //   1 WEEK SUSPENSION LENGTH OTHERWISE FAIL
            campaign.status = Status.Fail;
        } else {
            campaign.status = Status.Active; //CHANGE STATUS, REACTIVATE MILESTONES
            for (uint256 i = 0; i < milestones.length; i++) {
                if (milestones[i].status == Status.Inactive) {
                    milestones[i].status = Status.Active;
                }
            }
        }
        campaign.approvalCount = 0;
        // THE RELATIVE ARRAY AND MAPS ARE NOT TOUCHED SINCE WILL BE USED ONLY ONCE (ONLY ONE SUSPENSION ALLOWED)
    }

    // THE USER CAN CLICK ON THE CAMPAIGN TO VIEW DETAILS
    function getCampaignDetails() external view returns (CampaignInfo memory) {
        return campaign;
    }

    //ADDRESS OF THE CAMPAIGN IS THE ID
    function getContributorInfo(address campaignId, address contributor) external view returns (uint256) {
        return contributors[contributor][campaignId];
    }

    //CAMPAIGN ID IS NOT NEEDED IN THIS IMPLEMENTATION
    function getMilestoneStatus(uint256 milestoneIndex) external view returns (Milestones memory) {
        Milestones storage milestone = milestones[milestoneIndex];
        return milestone;
    }

    //CAMPAIGN ID IS NOT NEEDED  AS A PARAMETER IN THIS IMPLEMENTATION
    function getCampaignContributors() external view returns (address[] memory) {
        return contributorList;
    }

    //TOTAL CONTRIBUTIONS, BALANCE MAY DIFFER

    function getTotalContributions() external view returns (uint256) {
        return campaign.totalContribution;
    }

    //RESTRICTS THE CALL OF FUNCTIONS WHERE APPLIED TO OWNER ONLY
    modifier onlyOwner() {
        require(msg.sender == campaign.owner, "No Admin Rights.");
        _;
    }
}
