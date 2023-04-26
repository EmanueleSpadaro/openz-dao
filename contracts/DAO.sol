//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/AccessControl.sol";

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

    //Modifier that allows to execute the code only if the caller IS a member
    modifier isMember(address addr) {
        require(usersRole[addr] != 0x00, "you're required to be a member");
        _;
    }

    //Modifier that allows to execute the code only if the caller IS NOT a member
    modifier isNotMember(address addr) {
        require(usersRole[addr] == 0x00, "you're required to not be a member");
        _;
    }

    //Modifier that allows to execute the code only if the caller has a pending invitation
    modifier hasInvite() {
        require(invites[msg.sender] != 0, "no invite available for you");
        _;
    }

    //Modifier that allows to execute the code only if the caller is hierarchically superior in terms of rank
    modifier isAdminOf(address ofAddress) {
        require(isAdminOfRole(msg.sender, usersRole[ofAddress]), "you're required to be of higher rank");
        _;
    }

    //Modifier that extends the behaviour achievable with onlyRole(getRoleAdmin(role)) to hierarchically superior ranks 
    modifier onlyAdmins(bytes32 role) {
        require(isAdminOfRole(msg.sender, role), "only higher ranks of the given role are allowed");
        _;
    }

    event UserJoined(address indexed user, bytes32 asRole);
    event UserInvited(address indexed by, address user);
    event UserRankChanged(address indexed by, address user, bytes32 toRole, bool isPromotion);
    event UserKicked(address indexed by, address user);

    constructor(

    ){
        realm = "dao";
        owner = msg.sender;
        name = "Test_DAO";
        firstlifePlaceID = "paoloBorsellinoFID";
        description_cid = "La best residenza da quittare asap";
        isInviteOnly = false;
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
        delete invites[msg.sender];
        _grantRole(USER_ROLE, msg.sender);
        emit UserJoined(msg.sender, USER_ROLE);
    }
    
    //Invites a user with the given role to join the DAO
    function invite(address toInvite, bytes32 offeredRole) public isMember(msg.sender) isNotMember(toInvite) onlyAdmins(offeredRole) {
        invites[toInvite] = offeredRole;
        emit UserInvited(msg.sender, toInvite);
    }

    //Accepts an invite to the DAO
    function acceptInvite() public hasInvite{
        //We assign the role
        _grantRole(invites[msg.sender], msg.sender);
        //We delete the invite since it's been accepted
        invites[msg.sender] = 0;
        emit UserJoined(msg.sender, usersRole[msg.sender]);
    }

    //Declines an invite to the DAO
    function declineInvite() public hasInvite{
        //We delete the invite since it's been declined
        invites[msg.sender] = 0;
    }

    //Sets the rank of the given user to a new one, if we have enough permissions
    function modifyRank(address toModify, bytes32 newRole) public isMember(toModify) isAdminOf(toModify) onlyAdmins(newRole) {
        bool isPromotion = isAdminOfRole(newRole, usersRole[toModify]);
        _revokeRole(usersRole[toModify], toModify);
        _grantRole(newRole, toModify);
        emit UserRankChanged(msg.sender, toModify, newRole, isPromotion);
    }

    //Kicks a member if we have enough permissions
    function kickMember(address toKick) public isMember(toKick) isAdminOf(toKick) {
        _revokeRole(usersRole[toKick], toKick);
        emit UserKicked(msg.sender, toKick);
    }

    //Extended safe grantRole: allows only hierarchically superior ranks to execute it
    function grantRole(bytes32 role, address account) public virtual override onlyAdmins(role) isAdminOf(account) {
        _grantRole(role, account);
    }

    //Extended safe grantRole: allows only hierarchically superior ranks to execute it
    function revokeRole(bytes32 role, address account) public virtual override onlyAdmins(role) isAdminOf(account) {
        _revokeRole(role, account);
    }

    //Writes the new role to the role mapping, and then calls the base method
    function _grantRole(bytes32 role, address account) internal override {
        usersRole[account] = role;
        super._grantRole(role, account);
    }

    //Deletes the users role mapping value, and then calls the base method
    function _revokeRole(bytes32 role, address account) internal override {
        delete usersRole[account];
        super._revokeRole(role, account);
    }
}