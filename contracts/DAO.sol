//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/AccessControl.sol";

// Implementation questions
// 1. Whenever a user that has a pending invite joins autonomously the DAO, shall we assign him the USER_ROLE or the invitation one?

contract DAO is AccessControl {
    //External project requirement, it states "dao" to distinguish the DAO from standard user
    string public realm;
    //Address of the owner
    address public owner;

    //DAO's name, its uniqueness shall be managed by a Factory contract
    string public name;
    //External project requirement, it states the ID of a place inside a map. Each DAO has to be linked to a given place
    string public firstlifePlaceID;

    //External proejct requirement, DAO's description
    string public description_cid;
    //Specifies whether you can join this DAO freely or under invitation
    bool public isInviteOnly = false;



    //Rank system
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SUPERVISOR_ROLE = keccak256("SUPERVISOR_ROLE"); 
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");

    mapping(address => bytes32) usersRole;
    mapping (address=>bytes32) invites;
    //todo mapping(bytes32 => bool) validRoles; to check if the assigned roles are permitted?

    modifier isMember(address addr) {
        require(usersRole[addr] != 0x00, "you're required to be a member");
        _;
    }

    modifier isNotMember(address addr) {
        require(usersRole[addr] == 0x00, "you're required to not be a member");
        _;
    }

    modifier hasInvite() {
        require(invites[msg.sender] != 0, "no invite available for you");
        _;
    }

    modifier isAdminOf(address ofAddress) {
        require(isAdminOfRole(msg.sender, usersRole[ofAddress]), "you're required to be of higher rank");
        _;
    }

    constructor(

    ){
        realm = "dao";
        owner = msg.sender;
        name = "Test_DAO";
        firstlifePlaceID = "paoloBorsellinoFID";
        description_cid = "La best residenza da quittare asap";
        isInviteOnly = false;
        usersRole[msg.sender] = OWNER_ROLE;
        _grantRole(OWNER_ROLE, msg.sender);
        //We setup the role hierarchy in terms of admin role:
        //OWNER -> ADMIN -> SUPERVISOR -> USER
        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);
        _setRoleAdmin(SUPERVISOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(USER_ROLE, SUPERVISOR_ROLE);
    }

    function isAdminOfRole(bytes32 isAdminRole, bytes32 ofRole) public view returns(bool){
        bytes32 ofRoleAdminRole = getRoleAdmin(ofRole);
        while(ofRoleAdminRole != DEFAULT_ADMIN_ROLE){
            if(ofRoleAdminRole == isAdminRole){
                return true;
            }
            ofRoleAdminRole = getRoleAdmin(ofRoleAdminRole);
        }
        return isAdminRole == DEFAULT_ADMIN_ROLE;
    }

    function isAdminOfRole(address isAdmin, bytes32 ofRole) public view returns(bool){
        return isAdminOfRole(usersRole[isAdmin], ofRole);
    }

    //Joins the DAO
    function join() public isNotMember(msg.sender) {
        require(!isInviteOnly, "can't freely join invite-only dao");
        //todo We assign USER_ROLE, or if there's an invitation pending for msg.sender, the respective invitation role?
        usersRole[msg.sender] = USER_ROLE;
        _grantRole(USER_ROLE, msg.sender);
        //todo shall I emit an event?
    }
    
    //Invites a user with the given role to join the DAO
    function invite(address toInvite, bytes32 offeredRole) public isMember(msg.sender) isNotMember(toInvite) {
        require(isAdminOfRole(msg.sender, offeredRole), "not enough permissions to invite as given role");
        invites[toInvite] = offeredRole;
        //todo shall I emit an event?
    }

    //Accepts an invite to the DAO
    function acceptInvite() public hasInvite{
        //We assign the role
        usersRole[msg.sender] = invites[msg.sender];
        _grantRole(invites[msg.sender], msg.sender);
        //We delete the invite since it's been accepted
        invites[msg.sender] = 0;
        //todo shall I emit an event?
    }

    //Declines an invite to the DAO
    function declineInvite() public hasInvite{
        //We delete the invite since it's been declined
        invites[msg.sender] = 0;
        //Shall I emit an event?
    }

    //Sets the rank of the given user to a new one, if we have enough permissions
    function modifyRank(address toModify, bytes32 newRole) public isMember(toModify) isAdminOf(toModify) {
        //todo implement promotion/demotion rank accordingly to isPromotion if required
        //bool isPromotion = isAdminOfRole(newRole, usersRole[toModify]);
        _revokeRole(usersRole[toModify], toModify);
        usersRole[toModify] = newRole;
        _grantRole(newRole, toModify);
        //todo implement event? if so, shall i distinguish promotion && demotion?
    }

    //Kicks a member if we have enough permissions
    function kickMember(address toKick) public isMember(toKick) isAdminOf(toKick) {
        _revokeRole(usersRole[toKick], toKick);
        usersRole[toKick] = 0;
        //todo implement event?
    }
}