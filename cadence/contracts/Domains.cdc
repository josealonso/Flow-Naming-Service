import NonFungibleToken from "./interfaces/NonFungibleToken.cdc"
import FungibleToken from "./interfaces/FungibleToken.cdc"
import FlowToken from "./tokens/FlowToken.cdc"

// The Domains contract defines the Domains NFT Collection
// to be used by flow-name-service
pub contract Domains: NonFungibleToken {

/************************************************ Events **********************************************/
    pub event DomainBioChanged(nameHash: String, bio: String)
    pub event DomainAddressChanged(nameHash: String, address: Address)

    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event DomainMinted(id: UInt64, name: String, nameHash: String, expiresAt: UFix64, receiver: Address)

/**************************************** Global variables ********************************************/
    pub let owners: {String: Address}  // nameHash will be the key
    pub let expirationTimes: {String: UFix64}

    // A mapping for domain nameHash -> domain ID
    pub let nameHashToIDs: {String: UInt64}
    // A counter to keep track of how many domains have been minted
    pub var totalSupply: UInt64    
/************************************************ Structure ********************************************/    
    pub struct DomainInfo {
        pub let id: UInt64
        pub let owner: Address
        pub let name: String
        pub let nameHash: String
        pub let expiresAt: UFix64
        pub let address: Address?
        pub let bio: String
        pub let createdAt: UFix64

        // Struct initializer
        init(   // Ask
            id: UInt64,
            owner: Address,
            name: String,
            nameHash: String,
            expiresAt: UFix64,
            address: Address?,
            bio: String, 
            createdAt: UFix64,
        ) {
            self.id = id,
            self.owner = owner,
            self.name = name,
            self.nameHash = nameHash,
            self.expiresAt = expiresAt,
            self.address = address,
            self.bio = bio,
            self.createdAt = createdAt,
        }        
    }

/************************************************ Funtions *********************************************/
    // Checks if a domain is available for sale
    pub fun isAvailable(nameHash: String): Bool {
      if self.owners[nameHash] == nil {
        return true
    }
      return self.isExpired(nameHash: nameHash)
    }

    // Returns the expiry time for a domain
    pub fun getExpirationTime(nameHash: String): UFix64? {
      return self.expirationTimes[nameHash]
    }

    // Checks if a domain is expired
    pub fun isExpired(nameHash: String): Bool {
      let currTime = getCurrentBlock().timestamp
      let expTime = self.expirationTimes[nameHash]
      if expTime != nil {
        return currTime >= expTime!
      }
      return false
    }

    // Returns the entire `owners` dictionary
    pub fun getAllOwners(): {String: Address} {
      return self.owners
    }

    // Returns the entire `expirationTimes` dictionary
    pub fun getAllExpirationTimes(): {String: UFix64} {
      return self.expirationTimes
    }

    /*  NOTE access(self) allows the code within the smart contract to access that function/variable,
             whereas access(account) allows the account to access the function/variable - which includes the code itself as well.
    */
    // Update the owner of a domain
    access(account) fun updateOwner(nameHash: String, address: Address) {
      self.owners[nameHash] = address
    }

    // Update the expiration time of a domain
    access(account) fun updateExpirationTime(nameHash: String, expTime: UFix64) {
      self.expirationTimes[nameHash] = expTime
    }

    /********************* Helper functions for the Collection resource ********************************/

    pub fun getAllNameHashToIds(): {String: UInt64} {
      return self.nameHashToIDs
    }

    access(account) fun updateNameHashToID(nameHash: String, id: UInt64) {
      self.nameHashToIDs[nameHash] = id
    }

//********************************************** Start NFT resource interfaces ********************************************************/
    pub resource interface DomainPublic {
        pub let id: UInt64
        pub let name: String
        pub let nameHash: String
        pub let createdAt: UFix64   // and expiresAt ?

        pub fun getBio(): String
        pub fun getAddress(): Address?
        pub fun getDomainName(): String
        pub fun getInfo(): DomainInfo
    }

    pub resource interface DomainPrivate {
        pub fun setBio(bio: String)
        pub fun setAddress(addr: Address)
    }
//********************************************** Finish NFT resource interfaces ********************************************************/

//********************************************** Start NFT resource implementation ********************************************************/
    pub resource NFT: DomainPublic, DomainPrivate, DomainInfo, NonFungibleToken.INFT {
        pub let id: UInt64
        pub let name: String
        pub let nameHash: String
        pub let createdAt: UFix64  

        // access(self) implies that only the code within this resource
        // can read/modify this variable directly
        // This is similar to `private` in Solidity
        access(self) var address: Address?
        access(self) var bio: String

        init(id: UInt64, name: String, nameHash: String) {
            self.id = id,
            self.name = name,
            self.nameHash = nameHash,
            self.createdAt = getCurrentBlock().timestamp
            self.address = nil
            self.bio = ""
        }

        pub fun getBio(): String {
            return self.bio
        }

        pub fun setBio(bio: String) {
            // Ensure that the domain has not crossed its expire date
            // A 'pre'-check to running this function
            // If the condition is not valid, it will throw the given error
            pre {
              Domains.isExpired(nameHash: self.nameHash) == false : "Domain is expired"  // Ask
            }
            self.bio = bio
            emit DomainBioChanged(nameHash: self.nameHash, bio: bio)
        }

        pub fun getAddress(): Address? {
            return self.address
        }

        pub fun setAddress(addr: Address) {
            // Ensure that the domain has not crossed its expire date
            pre {
              Domains.isExpired(nameHash: self.nameHash) == false : "Domain is expired"  // Ask
            }
            self.address = addr
            emit DomainAddressChanged(nameHash: self.nameHash, address: addr)
        }

        pub fun getDomainName(): String {
            return self.name.concat(".fns")
        }

        pub fun getInfo(): DomainInfo {
            let owner = Domains.owners[self.nameHash]! 

            return DomainInfo(
              id: self.id,
              owner: owner,
              name: self.getDomainName(),
              nameHash: self.nameHash,
              expiresAt: Domains.expirationTimes[self.nameHash]!,
              address: self.address,
              bio: self.bio,
              createdAt: self.createdAt
            )
        }
    }

//********************************************** Collection resource interfaces ********************************************************/
    pub resource interface CollectionPublic {
        pub fun borrowDomain(id: UInt64): &{Domains.DomainPublic}
    }

    pub resource interface CollectionPrivate {
        acces(account) fun mintDomain(name: String, nameHash: String, expiresAt: UFix64, receiver: Capability<@{NonFungibleToken.Receiver}>)
        pub fun borrowDomainPrivate(id: UInt64): &Domains.NFT
    }

//********************************************** Collection resource implementation ********************************************************/
    pub resource Collection: CollectionPublic, CollectionPrivate, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init() {
          // Initialize as an empty resource
          self.ownedNFTs <- {}
        }

        // NonFungibleToken.Provider
        /* You have to think of this as a user interacting with their personal NFT collection stored in their account storage. 
           They get access to their collection, call the withdraw function on it, get access to a specific NFT resource, 
           and then do whatever they want with it. */
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
          let domain <- self.ownedNFTs.remove(key: withdrawID)
              ?? panic("NFT not found in collection")
          emit Withdraw(id: domain.id, from: self.owner?.address)
          return <- domain
        }

        // NonFungibleToken.Receiver
        pub fun deposit(token: @NonFungibleToken.NFT) {
          // Typecast the generic NFT resource as a Domains.NFT resouce
          let domain <- token as! @Domains.NFT
          let id = domain.id
          let nameHash = domain.nameHash

          if Domains.isExpired(nameHash: nameHash) {
            panic("Domain is expired")
          }

          Domains.updateOwner(nameHash: nameHash, address: self.owner?.address)
          let oldToken <- self.ownedNFTs[id] <- domain
          emit Deposit(id: id, to: self.owner?.address)

          destroy oldToken
        }

        // NonFungibleToken.CollectionPublic
        pub fun getIDs(): [UInt64] {
          // Not possible in Solidity
          return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
          return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        // Domains.CollectionPublic
        pub fun borrowDomain(id: UInt64): &{Domains.DomainPublic} {
          pre {
            self.ownedNFTs[id] != nil : "Domain does not exist"
          }

          let token = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
          return token as! &Domains.NFT
        }

        // Domains.CollectionPrivate
        access(account) fun mintDomain(name: String, nameHash: String, expiresAt: UFix64, receiver: Capability<&{NonFungibleToken.Receiver}>) {
          pre {
            Domains.isAvailable(nameHash: nameHash) : "Domain not available"
          }

          let domain <- create Domains.NFT(
            id: Domains.totalSupply,
            name: name,
            nameHash: nameHash
          )

          Domains.updateOwner(nameHash: nameHash, address: receiver.address)
          Domains.updateExpirationTime(nameHash: nameHash, expTime: expiresAt)
          Domains.updateNameHashToID(nameHash: nameHash, id: domain.id)
          Domains.totalSupply = Domains.totalSupply + 1

          emit DomainMinted(id: domain.id, name: name, nameHash: nameHash, expiresAt: expiresAt, receiver: receiver.address)

          receiver.borrow()!.deposit(token: <- domain)
        }

        pub fun borrowDomainPrivate(id: UInt64): &Domains.NFT {
          pre {
            self.ownedNFTs[id] != nil: "Domain does not exist"
          }
          let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
          return ref as! &Domains.NFT
        }

        destroy() {
          destroy self.ownedNFTs
        } 

    }

}
