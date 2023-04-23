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

    modifier isMember() {
        //todo maybe implement the modifier so that if checkee is 0x00 it manages the msg.sender or checkee
        require(usersRole[msg.sender] != 0x00, "you're required to be a member");
        _;
    }

    modifier isNotMember() {
        //todo maybe implement the modifier so that if checkee is 0x00 it manages the msg.sender or checkee
        require(usersRole[msg.sender] == 0x00, "you're required to not be a member");
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

    //todo farlo modifier? si o no?
    function isAdminOfRole(address isAdmin, bytes32 ofRole) public view returns(bool){
        //todo caller && callee should be members
        bytes32 isAdminRole = usersRole[isAdmin];
        //We retrieve the callee's first upper admin role in the hierarchy to go up the ladder
        bytes32 ofRoleAdminRole = getRoleAdmin(ofRole);
        while(ofRoleAdminRole != DEFAULT_ADMIN_ROLE){
            if(ofRoleAdminRole == isAdminRole){
                return true;
            }
            ofRoleAdminRole = getRoleAdmin(ofRoleAdminRole);
        }
        return hasRole(DEFAULT_ADMIN_ROLE, isAdmin);
    }

    modifier isAdminOf(address ofAddress) {
        require(isAdminOfRole(msg.sender, usersRole[ofAddress]), "you're required to be of higher rank");
        _;
    }



    function join() public isNotMember {
        require(!isInviteOnly, "can't freely join invite-only dao");
        usersRole[msg.sender] = USER_ROLE;
        _grantRole(USER_ROLE, msg.sender);
    }
    //If there's an actual invite for msg.sender
    modifier hasInvite() {
        require(invites[msg.sender] != 0, "no invite available for you");
        _;
    }
    mapping (address=>bytes32) invites;

    function invite(address toInvite, bytes32 offeredRole) public {
        //todo require that toInvite isnt an actual member, there would be no reason to let people invite an already member
        require(isAdminOfRole(msg.sender, offeredRole), "not enough permissions to invite as given role");
        require(usersRole[toInvite] == 0x00, "cannot invite an already member");
        // require(hasRole(getRoleAdmin(offeredRole), msg.sender), "not enough permissions to invite as given role");
        invites[toInvite] = offeredRole;
    }

    //Accepts an invite to the DAO
    function acceptInvite() public hasInvite{
        //We assign the role
        usersRole[msg.sender] = invites[msg.sender];
        _grantRole(invites[msg.sender], msg.sender);
        //We delete the invite since it's been accepted
        invites[msg.sender] = 0;
    }
    //Declines an invite to the DAO
    function declineInvite() public hasInvite{
        //We delete the invite since it's been declined
        invites[msg.sender] = 0;
    }


}