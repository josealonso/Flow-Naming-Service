import NonFungibleToken from "./interfaces/NonFungibleToken.cdc"
import FungibleToken from "./interfaces/FungibleToken.cdc"
import FlowToken from "./tokens/FlowToken.cdc"

// The Domains contract defines the Domains NFT Collection
// to be used by flow-name-service
pub contract Domains: NonFungibleToken {
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
        init(
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

    pub resource interface DomainPublic {
        pub let id: UInt64
        pub let name: String
        pub let nameHash: String
        pub let createdAt: UFix64   // and espiresAt ?

        pub fun getBio(): String
        pub fun getAddress(): Address?
        pub fun getDomainName(): String
        pub fun getInfo(): DomainInfo
    }

    pub resource interface DomainPrivate {
        pub fun setBio(bio: String)
        pub fun setAddress(addr: Address)
    }

}