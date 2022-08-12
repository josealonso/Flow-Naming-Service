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
    pub event DomainRenewed(id: UInt64, name: String, nameHash: String, expiresAt: UFix64, receiver: Address)

/**************************************** Global variables ********************************************/
    pub let owners: {String: Address}  // nameHash will be the key
    pub let expirationTimes: {String: UFix64}

    // A mapping for domain nameHash -> domain ID
    pub let nameHashToIDs: {String: UInt64}
    // A counter to keep track of how many domains have been minted
    pub var totalSupply: UInt64    

    // Defines forbidden characters within domain names - such as .
    pub let forbiddenChars: String
    // Defines the minimum duration a domain must be rented for
    pub let minRentDuration: UFix64
    // Defines the maximum length of the domain name (not including .fns)
    pub let maxDomainLength: Int

//******************** The Initializer **************/
    init() {
      self.owners = {}
      self.expirationTimes = {}
      self.nameHashToIDs = {}

      // Define forbidden characters for domain names
      self.forbiddenChars = "!@#$%^&*()<>? ./"
      // Initialize total supply to 0
      self.totalSupply = 0

      // Set the various paths to store `Domains.Collection` at in a user's account storage
      self.DomainsStoragePath = StoragePath(identifier: "flowNameServiceDomains") ?? panic("Could not set storage path")
      self.DomainsPrivatePath = PrivatePath(identifier: "flowNameServiceDomains") ?? panic("Could not set private path")
      self.DomainsPublicPath = PublicPath(identifier: "flowNameServiceDomains") ?? panic("Could not set public path")

      // Set the various paths to store `Domains.Registrar` in the admin account's storage
      self.RegistrarStoragePath = StoragePath(identifier: "flowNameServiceRegistrar") ?? panic("Could not set storage path")
      self.RegistrarPrivatePath = PrivatePath(identifier: "flowNameServiceRegistrar") ?? panic("Could not set private path")
      self.RegistrarPublicPath = PublicPath(identifier: "flowNameServiceRegistrar") ?? panic("Could not set public path")

      // Here's the fun stuff
    
      // self.account refers to the account where the smart contract lives, i.e. the admin account
    
      // 1. Create an empty Domains.Collection resource
      // 2. Save it to the admin account's storage path
      self.account.save(<- self.createEmptyCollection(), to: Domains.DomainsStoragePath)
   
      // 3. Link the Public resource interfaces that we are okay sharing with third-parties
      // to the public account storage from the main storage path
      // All objects in public paths can be accessed by anyone
      self.account.link<&Domains.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, Domains.CollectionPublic}>
        (self.DomainsPublicPath, target: self.DomainsStoragePath)
    
      // 4. Link the overall resource (public + private) to the private storage path from the main storage path
      // This allows us to create capabilities if necessary.
      // This is needed because Capabilities can only be created from public or private paths, not from the main storage path
      // for security reasons
      self.account.link<&Domains.Collection>(self.DomainsPrivatePath, target: self.DomainsStoragePath)

      // Now, get a capability from the private path for Domains.Collection from the admin account
      // We will pass this onto the Registrar resource (to be created)
      // So it has access to the Private functions within Domains.Collection, specifically, `mintDomain`
      let collectionCapability = self.account.getCapability<&Domains.Collection>(self.DomainsPrivatePath)
    
      // Create an empty FungibleToken.Vault for the FlowToken
      // This is the one and only time we utilize the FlowToken import
      let vault <- FlowToken.createEmptyVault()
      // Create a Registrar resource, and give it the Vault 
      // and the Private Collection Capability
      let registrar <- create Registrar(vault: <- vault, collection: collectionCapability)
    
      // Now save the Registrar resource in the admin account's main storage path
      self.account.save(<- registrar, to: self.RegistrarStoragePath)
   
      // Link the Public portion of the Registrar to the public path
      // for the Registrar resource
      self.account.link<&Domains.Registrar{Domains.RegistrarPublic}>(self.RegistrarPublicPath, target: self.RegistrarStoragePath)
      // Link the overall resource (public + private) to the 
      // private path for the Registrar Resource
      self.account.link<&Domains.Registrar>(self.RegistrarPrivatePath, target: self.RegistrarStoragePath)

      // Emit the ContractInitialized event
      emit ContractInitialized()
    }

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

    /********************* Helper functions for the Registrar resource ********************************/
    pub fun getDomainNameHash(name: String): String {
      let forbiddenCharsUTF8 = self.forbiddenChars.utf8
      let nameUTF8 = name.utf8

      for char in forbiddenCharsUTF8 {
        if nameUTF8.contains(char) {
          panic("Illegal domain name")
        }
      }

      // Calculate the SHA-256 hash, and encode it as a Hexadecimal string
      let nameHash = String.encodeHex(HashAlgorithm.SHA3_256.hash(nameUTF8))
      return nameHash
    }

    /********************* Global functions ********************************/
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
      let collection <- create Collection()
      return <- collection
    }

    pub fun getRentCost(name: String, duration: UFix64): UFix64 {
      var len = name.length
      if len > 10 {
        len = 10
      } 
      let price = self.getPrices()[len]
      let rentCost = price! * duration
      return rentCost
    }

    //******************** Used by the Initializer **************/
    // Storage, Public, and Private paths for Domains.Collection resource
    pub let DomainsStoragePath: StoragePath
    pub let DomainsPrivatePath: PrivatePath
    pub let DomainsPublicPath: PublicPath

    // Storage, Public, and Private paths for Domains.Registrar resource
    pub let RegistrarStoragePath: StoragePath
    pub let RegistrarPrivatePath: PrivatePath
    pub let RegistrarPublicPath: PublicPath

    // Event that implies a contract has been initialized
    // Required by the NonFungibleToken standard
    pub event ContractInitialized()

    pub fun getVaultBalance(): UFix64 {
      let cap = self.account.getCapability<&Domains.Registrar{Domains.RegistrarPublic}>(Domains.RegistrarPublicPath)
      let registrar = cap.borrow() ?? panic("Could not borrow registrar public")
      return registrar.getVaultBalance()
    }

    pub fun registerDomain(name: String, duration: UFix64, feeTokens: @FungibleToken.Vault, receiver: Capability<&{NonFungibleToken.Receiver}>) {
      let cap = self.account.getCapability<&Domains.Registrar{Domains.RegistrarPublic}>(self.RegistrarPublicPath)
      let registrar = cap.borrow() ?? panic("Could not borrow registrar")
      registrar.registerDomain(name: name, duration: duration, feeTokens: <- feeTokens, receiver: receiver)
    }

    pub fun renewDomain(domain: &Domains.NFT, duration: UFix64, feeTokens: @FungibleToken.Vault) {
      let cap = self.account.getCapability<&Domains.Registrar{Domains.RegistrarPublic}>(self.RegistrarPublicPath)
      let registrar = cap.borrow() ?? panic("Could not borrow registrar")
      registrar.renewDomain(domain: domain, duration: duration, feeTokens: <- feeTokens)
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

//************************************************** Registrar resource interfaces ********************************************************/
    pub resource interface RegistrarPublic {
        pub let minRentDuration: UFix64
        pub let maxDomainLength: Int
        pub let prices: {Int: UFix64}

        pub fun renewDomain(domain: &Domains.NFT, duration: UFix64, feeTokens: @FungibleToken.Vault)
        pub fun registerDomain(name: String, duration: UFix64, feeTokens: @FungibleToken.Vault, receiver: Capability<&{NonFungibleToken.Receiver}>)
        pub fun getPrices(): {Int: UFix64}
        pub fun getVaultBalance(): UFix64  // how many Flow tokens have been earned by selling domain names
    }

    pub resource interface RegistrarPrivate {
        pub fun updateRentVault(vault: @FungibleToken.Vault)
        pub fun withdrawVault(receiver: Capability<&{FungibleToken.Receiver}>, amount: UFix64)
        pub fun setPrices(key: Int, val: UFix64)
    }

//************************************************** Registrar resource implementation ****************************************************/
    pub resource Registrar: RegistrarPublic, RegistrarPrivate {
        // Variables defined in the interfaces
        pub let minRentDuration: UFix64
        pub let maxDomainLength: Int
        pub let prices: {Int: UFix64}

        // A reference to the Vault used for depositing Flow tokens we receive
        // `priv` variables cannot be defined in interfaces
        // `priv` = `private`. It is a shorthand for access(self)
        priv var rentVault: @FungibleToken.Vault

        // A capability for the Domains.Collection resource owned by the account
        // Only the account has access to it
        // We will use this to access the account-only `mintDomain` function
        // Within the Collection owned by our smart contract account
        acces(account) var domainsCollection: Capability<&Domains.Collection>

        init(vault: @FungibleToken.Vault, collection: Capability<&Domains.Collection>) {
          // This represents 1 year in seconds
          self.minRentDuration = UFix64(365 * 24 * 60 * 60)
          self.maxDomainLength = 30
          self.prices = {}

          self.rentVault <- vault
          self.domainsCollection = collection
        }        

        pub fun renewDomain(domain: &Domains.NFT, duration: UFix64, feeTokens: @FungibleToken.Vault) {
            // We don't need to check if the user owns this domain
            // because they are providing us a full reference to Domains.NFT
            // through the first argument.
            // They could not have done this if they did not own the domain
  
            var len = domain.name.length
            // If the length of the domain name is >10,
            // Make the arbitrary decision to price it the same way
            // as if it was 10 characters long
            if len > 10 {
              len = 10
            }

            // Get the price per second of rental for this length of domain
            let price = self.getPrices()[len]

            // Ensure that the duration to rent for isn't less than the minimum
            if duration < self.minRentDuration {
              panic("Domain must be registered for at least the minimum duration: ".concat(self.minRentDuration.toString()))
            }

            // Ensure that the admin has set a price for this domain length
            if price == 0.0 || price == nil {
               panic("Price has not been set for this length of domain")
            }

            // Calculate total rental cost (price * duration)
            let rentCost = price! * duration
            // Check the balance of the Vault given to us by the user
            // This is their way of sending us tokens through the transaction
            let feeSent = feeTokens.balance

            // Ensure they've sent >= tokens as required
            if feeSent < rentCost {
              panic("You did not send enough FLOW tokens. Expected: ".concat(rentCost.toString()))
            }

            // If yes, deposit those tokens into our own rentVault
            self.rentVault.deposit(from: <- feeTokens)

            // Calculate the new expiration date for this domain
            // Add duration of rental to current expiry date
            // and update the expiration time
            let newExpTime = Domains.getExpirationTime(nameHash: domain.nameHash)! + duration
            Domains.updateExpirationTime(nameHash: domain.nameHash, expTime: newExpTime)

            // emit the DomainRenewed event
            emit DomainRenewed(id: domain.id, name: domain.name, nameHash: domain.nameHash, expiresAt: newExpTime, receiver: domain.owner!.address)
        }
  
        pub fun registerDomain(name: String, duration: UFix64, feeTokens: @FungibleToken.Vault, receiver: Capability<&{NonFungibleToken.Receiver}>) {
            // Ensure the domain name is not longer than the max length allowed
            pre {
              name.length <= self.maxDomainLength : "Domain name is too long"
            }

            // Hash the name and get the nameHash
            let nameHash = Domains.getDomainNameHash(name: name)

            // Ensure the domain is available for sale
            if Domains.isAvailable(nameHash: nameHash) == false {
              panic("Domain is not available")
            }

            // Same as renew, price any domain >10 characters the same way
            // as a domain with 10 characters
            var len = name.length
            if len > 10 {
              len = 10
            }

            // All the calculations are the same as renew
            let price = self.getPrices()[len]

            if duration < self.minRentDuration {
              panic("Domain must be registered for at least the minimum duration: ".concat(self.minRentDuration.toString()))
            }

            if price == 0.0 || price == nil {
              panic("Price has not been set for this length of domain")
            }

            let rentCost = price! * duration
            let feeSent = feeTokens.balance

            if feeSent < rentCost {
              panic("You did not send enough FLOW tokens. Expected: ".concat(rentCost.toString()))
            }

            self.rentVault.deposit(from: <- feeTokens)

            // Calculate the expiry time for the domain by adding duration
            // to the current timestamp
            let expirationTime = getCurrentBlock().timestamp + duration

            // Use the domainsCollection capability of the admin to mint the new domain
            // and transfer it to the receiver
            self.domainsCollection.borrow()!.mintDomain(name: name, nameHash: nameHash, expiresAt: expirationTime, receiver: receiver)

            // DomainMinted event is emitted from mintDomain ^
          }

        // Return the prices dictionary
        pub fun getPrices(): {Int: UFix64} {
          return self.prices
        }

        pub fun getVaultBalance(): UFix64 {
          return self.rentVault.balance
        }

        pub fun updateRentVault(vault: @FungibleToken.Vault) {
          // Make sure current value doesn't have any remaining tokens before updating it
          pre {
            self.rentVault.balance == 0.0 : "Withdraw balance from old vault before updating it"
          }

          let oldVault <- self.rentVault <- vault
          destroy oldVault
        }

        pub fun withdrawVault(receiver: Capability<&{FungibleToken.Receiver}>, amount: UFix64) {
          let vault = receiver.borrow()!
          vault.deposit(from: <-self.rentVault.withdraw(amount: amount))
        }

        // Update the prices of domains for a given length
        pub fun setPrices(key: Int, val: UFix64) {
          self.prices[key] = val
        }

        // A destructor is needed since the Registrar resource contains other resources within it, specifically the FungibleToken.Vault.
        destroy() {
          destroy self.rentVault
        }
    }

}














