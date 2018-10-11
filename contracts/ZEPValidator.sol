pragma solidity ^0.4.24;

import "openzeppelin-zos/contracts/Initializable.sol";
import 'openzeppelin-zos/contracts/ownership/Ownable.sol';
import 'openzeppelin-zos/contracts/lifecycle/Pausable.sol';
import './AttributeRegistry.sol';
import './BasicJurisdictionInterface.sol';

contract ZEPValidator is Initializable, Ownable, Pausable {

  event OrganizationAdded(address organization, string name);
  event AttributeIssued(address indexed organization, address attributedAddress);
  event AttributeRevoked(address indexed organization, address attributedAddress);

  // declare registry interface, used to request attributes from a jurisdiction
  AttributeRegistry registry;

  // declare jurisdiction interface, used to set attributes in the jurisdiction
  BasicJurisdictionInterface jurisdiction;

  // declare the attribute ID required by ZEP in order to transfer tokens
  uint256 validAttributeID;

  // organizations are entities who can add attibutes to a number of addresses
  struct Organization {
    bool exists;
    uint248 maximumAddresses;
    string name;
    address[] addresses;
    mapping(address => bool) issuedAddresses;
    mapping(address => uint256) issuedAddressesIndex;
  }

  // addresses of all organizations are held in an array (enables enumeration)
  address[] private organizationAddresses;

  // organization data & issued attribute addresses are held in a struct mapping
  mapping(address => Organization) private organizations;

  // the initializer will attach the validator to a jurisdiction & set attribute
  function initialize(
    address _jurisdiction,
    uint256 _validAttributeID
  )
    initializer
    public
  {
    Ownable.initialize(msg.sender);
    Pausable.initialize(msg.sender);
    registry = AttributeRegistry(_jurisdiction);
    jurisdiction = BasicJurisdictionInterface(_jurisdiction);
    validAttributeID = _validAttributeID;
    // NOTE: we can require that the jurisdiction implements the right interface
    // using EIP-165 or that the contract is designated as a validator and has
    // authority to issue attributes of the specified type here if desired
  }

  // the contract owner may add new organizations
  function addOrganization(
    address _organization,
    uint248 _maximumAddresses,
    string _name
  ) external onlyOwner {
    // check that an empty address was not provided by mistake
    require(_organization != address(0), "must supply a valid address");

    // prevent existing organizations from being overwritten
    require(
      organizations[_organization].exists == false,
      "an organization already exists at the provided address"
    );

    // set up the organization in the organizations mapping
    organizations[_organization].exists = true;
    organizations[_organization].maximumAddresses = _maximumAddresses;
    organizations[_organization].name = _name;
    
    // add the organization to the end of the organizationAddresses array
    organizationAddresses.push(_organization);

    // log the addition of the organization
    emit OrganizationAdded(_organization, _name);
  }

  // the owner may modify the max number addresses a organization can issue
  function setMaximumAddresses(
    address _organization,
    uint248 _maximum
  ) external onlyOwner {
    // make sure the organization exists
    require(
      organizations[_organization].exists == true,
      "an organization does not exist at the provided address"
    );

    // make sure that maximum is not set below the current number of addresses
    // NOTE: this feature, coupled with the ability to revoke attributes, will
    // prevent an organization from being 'frozen' since the organization can
    // remove an address and then add an arbitrary address in its place. Options
    // to address this include a dedicated method to freeze organizations, or a
    // special exception to the requirement below that allows the maximum to be
    // set to 0 which will achieve the intended effect.
    require(
      organizations[_organization].addresses.length <= _maximum,
      "maximum cannot be set to amounts less than the current address total"
    );

    // set the organization's maximum addresses; a value == current freezes them
    organizations[_organization].maximumAddresses = _maximum;
  }

  // an organization can add an attibute to an address if maximum isn't exceeded
  // (NOTE: this function would need to be payable if a jurisdiction fee is set)
  function issueAttribute(address _who) external whenNotPaused {
    // check that an empty address was not provided by mistake
    require(_who != address(0), "must supply a valid address");

    // make sure the request is coming from a valid organization
    require(
      organizations[msg.sender].exists == true,
      "only organizations may issue attributes"
    );

    // ensure that the maximum has not been reached yet
    uint256 maximum = uint256(organizations[msg.sender].maximumAddresses);
    require(
      organizations[msg.sender].addresses.length < maximum,
      "the organization is not permitted to issue any additional attributes"
    );
 
    // assign the attribute to the jurisdiction (NOTE: a value is not required)
    jurisdiction.addAttributeTo(_who, validAttributeID, 0);

    // ensure that the attribute was correctly assigned
    require(
      registry.hasAttribute(_who, validAttributeID) == true,
      "attribute addition was not accepted by the jurisdiction"
    );

    // add the address to the mapping of issued addresses
    organizations[msg.sender].issuedAddresses[_who] = true;

    // add the index of the address to the mapping of issued addresses
    uint256 index = organizations[msg.sender].addresses.length;
    organizations[msg.sender].issuedAddressesIndex[_who] = index;

    // add the address to the end of the organization's `addresses` array
    organizations[msg.sender].addresses.push(_who);
    
    // log the addition of the new attributed address
    emit AttributeIssued(msg.sender, _who);
  }

  // an organization can revoke an attibute from an address
  function revokeAttribute(address _who) external whenNotPaused {
    // check that an empty address was not provided by mistake
    require(_who != address(0), "must supply a valid address");

    // make sure the request is coming from a valid organization
    require(
      organizations[msg.sender].exists == true,
      "only organizations may revoke attributes"
    );

    // ensure that the address has been issued an attribute
    require(
      organizations[msg.sender].issuedAddresses[_who] &&
      organizations[msg.sender].addresses.length > 0,
      "the organization is not permitted to revoke an unissued attribute"
    );
 
    // remove the attribute to the jurisdiction
    jurisdiction.removeAttributeFrom(_who, validAttributeID);

    // ensure that the attribute was correctly removed
    require(
      registry.hasAttribute(_who, validAttributeID) == false,
      "attribute revocation was not accepted by the jurisdiction"
    );

    // get the address at the last index of the array
    uint256 lastIndex = organizations[msg.sender].addresses.length - 1;
    address lastAddress = organizations[msg.sender].addresses[lastIndex];

    // get the index to delete
    uint256 indexToDelete = organizations[msg.sender].issuedAddressesIndex[_who];

    // set the address at indexToDelete to last address
    organizations[msg.sender].addresses[indexToDelete] = lastAddress;

    // update the index of the address that was moved
    organizations[msg.sender].issuedAddressesIndex[lastAddress] = indexToDelete;
    
    // remove the (now duplicate) address at the end & trim the array
    delete organizations[msg.sender].addresses[lastIndex];
    organizations[msg.sender].addresses.length--;
    
    // log the addition of the new attributed address
    emit AttributeRevoked(msg.sender, _who);
  }

  // external interface for checking address of the jurisdiction validator uses
  function getJurisdictionAddress() external view returns (address) {
    return address(jurisdiction);
  }

  // external interface for getting a list of organization addresses
  function getOrganizations() external view returns (address[] addresses) {
    return organizationAddresses;
  }

  // external interface for getting all the details of a particular organization
  function getOrganization(address _organization) external view returns (
    bool exists,
    uint248 maximumAddresses,
    string name,
    address[] issuedAddresses
  ) {
    return (
      organizations[_organization].exists,
      organizations[_organization].maximumAddresses,
      organizations[_organization].name,
      organizations[_organization].addresses
    );
  }
}