pragma solidity >=0.7.0 <0.9.0;

import {Script, console} from "forge-std/Script.sol";
import {CampaignGenerator} from "../src/Crowdfund.sol";


contract Crowdfund is Script{


 CampaignGenerator public campgen;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        campgen = new CampaignGenerator();

        vm.stopBroadcast();
    }

}