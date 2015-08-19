import CloudKit
import Internet
import ReachabilitySwift


public struct Options
{
    public enum Access
    {
        case Public, Private
    }
    
    public enum Permission
    {
        case ReadOnly, ReadWrite
    }
    
    public enum MergePolicy
    {
        case LocalFirst, ServerFirst
    }
    
    public let container: CKContainer
    public let access: Access
    public let permission: Permission
    public let mergePolicy: MergePolicy
    
    public static func forPublicContainer() -> Options
    {
        return Options(access: .Public, permission: .ReadOnly, mergePolicy: .ServerFirst)!
    }
    
    public static func forAccess(access: Access) -> Options
    {
        return Options(access: access, permission: .ReadWrite, mergePolicy: .LocalFirst)!
    }
    
    public init?(access: Access, permission: Permission, mergePolicy policy: MergePolicy, cloudKitContainer container: CKContainer = CKContainer.defaultContainer(), reachability: Reachability = Reachability(hostname: "api.apple-cloudkit.com"))
    {
        if access == .Private && permission == .ReadOnly {
            assertionFailure("You must not create a Cloud Access to the private database with a readonly permission.")
            return nil
        }
        self.container = container
        self.access = access
        self.permission = permission
        self.mergePolicy = policy
        Internet.start(reachability)
    }
    
    internal func needCloudKitPermissions() -> Bool
    {
        if self.access == .Public {
            return self.permission != .ReadOnly
        }
        return true
    }
}