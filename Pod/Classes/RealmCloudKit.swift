import MultiRealm
import RealmSwift
import CloudKit
import SwiftFileManager
import Backgroundable
import KeychainAccess
import Security
import Internet
import ReachabilitySwift


internal let domain = "com.bellapplab.RealmCloudKit"
internal let bundle = NSBundle(identifier: "org.cocoapods.RealmCloudKit")!


public final class RealmCloudKit
{
    deinit
    {
        Internet.removeChangeBlock(self.internetChange)
        Internet.pause()
    }
    
    private let backgroundRealm: MultiRealm
    private let cloudKitRealm: MultiRealm
    private var internetChange: InternetChange!
    private func setupInternetChange() {
        self.internetChange = Internet.addChangeBlock { [unowned self] (status: Reachability.NetworkStatus) -> Void in
            self.suspended = status == .NotReachable
        }
    }
    private let options: Options
    private var suspendedCount = 0
    private var isSuspended: Bool {
        return suspendedCount > 0
    }
    private func suspend()
    {
        
    }
    private func resume()
    {
        
    }
    
    private init(pathToRealmToBeSynced: String, encryptionKey: NSData?, pathToCloudKitRealm: String, options: Options) {
        self.backgroundRealm = MultiRealm(path: pathToRealmToBeSynced, readOnly: false, encryptionKey: encryptionKey, queueType: .Background)
        self.options = options
        self.path = pathToCloudKitRealm
        
        self.suspendedCount++
        if !Internet.areYouThere() {
            suspendedCount++
        }
        
        let keychain = Keychain(service: domain).accessibility(.WhenUnlockedThisDeviceOnly)
        var password = keychain.getData("RealmCloudKit")
        if password == nil {
            // Generate a random encryption key
            let key = NSMutableData(length: 64)!
            SecRandomCopyBytes(kSecRandomDefault, key.length,
                UnsafeMutablePointer<UInt8>(key.mutableBytes))
            keychain.set(key, key: "RealmCloudKit")
            password = key
        }
        self.cloudKitRealm = MultiRealm(path: self.path, readOnly: false, encryptionKey: password!, queueType: .Background)
        
        self.setupInternetChange()
    }
    
    public class func start(realmToBeSynced realm: Realm, block: (resultRealm: RealmCloudKit?, error: NSError?) -> Void) {
        self.start(pathToRealmToBeSynced: realm.path, block: block)
    }
    
    public class func start(pathToRealmToBeSynced path: String?, block: (resultRealm: RealmCloudKit?, error: NSError?) -> Void) {
        self.start(pathToRealmToBeSynced: path, encryptionKey: nil, options: nil, block: block)
    }
    
    public class func start(var pathToRealmToBeSynced path: String?, encryptionKey: NSData?, var options: Options?, block: (resultRealm: RealmCloudKit?, error: NSError?) -> Void) {
        if options == nil {
            options = Options.forPublicContainer()
        }
        if path == nil || path!.isEmpty {
            path = Realm.defaultPath
        }
        
        let errorBlock: (NSError)->() = { (anError: NSError) -> () in
            toMainThread {
                block(resultRealm: nil, error: anError)
            }
        }
        
        //Getting the Cloud Kit Realm's URL
        NSFileManager.URLForFile(.Database, withName: path!.lastPathComponent) { (urlSuccess, cloudKitRealmURL) -> Void in
            if !urlSuccess {
                errorBlock(RealmCloudKitError.Denied.produceError())
            } else {
                let deleteBlock: ((()->())?)->() = { (deleteReturnBlock: (()->())?) in
                    NSFileManager.deleteFile(cloudKitRealmURL!, withBlock: { (success, finalURL) -> Void in
                        deleteReturnBlock?()
                    })
                }
                
                let startBlock: ()->() = {
                    toBackground {
                        let result = RealmCloudKit(pathToRealmToBeSynced: path!, encryptionKey: encryptionKey, pathToCloudKitRealm: cloudKitRealmURL!.path!, options: options!)
                        toMainThread {
                            block(resultRealm: result, error: nil)
                        }
                    }
                }
                
                if !options!.needCloudKitPermissions()
                {//It doesn't matter if the user doesn't have an iCloud account set up
                    startBlock()
                }
                else
                {//We need an iCloud account
                    getCloudAccount(options!, deleteBlock, { (success: Bool, error: NSError?) -> Void in
                        if !success {
                            errorBlock(error!)
                        } else {
                            startBlock()
                        }
                    })
                }
            }
        }
    }
    
    public let path: String
    
    public var suspended: Bool {
        get {
            return self.isSuspended
        }
        set {
            if newValue {
                if !self.isSuspended {
                    self.suspend()
                }
                suspendedCount++
            } else {
                if suspendedCount == 1 {
                    self.resume()
                }
                suspendedCount--
                if suspendedCount < 0 {
                    suspendedCount == 0
                }
            }
        }
    }
    
}


//MARK: - Errors

public enum RealmCloudKitError: Int
{
    case Denied = 1 //User chose not to use iCloud
    case PasswordMiss = 2 //User hasn't set up an iCloud account and doesn't want to set it
    case TurnedOff = 3 //IPromiseTheUserWantsToUseiCloud option in NSUserDefaults is set to false
    case Restricted = 4 //iCloud access is restricted on the device
    
    public var description: String {
        switch self
        {
        case .Denied: return NSLocalizedString("Denied", tableName: "RealmCloudKit", bundle: bundle, comment: "Error code's description")
        case .PasswordMiss: return NSLocalizedString("PasswordMiss", tableName: "RealmCloudKit", bundle: bundle, comment: "Error code's description")
        case .TurnedOff: return NSLocalizedString("TurnedOff", tableName: "RealmCloudKit", bundle: bundle, comment: "Error code's description")
        case .Restricted: return NSLocalizedString("Restricted", tableName: "RealmCloudKit", bundle: bundle, comment: "Error code's description")
        }
    }
    
    internal func produceError() -> NSError
    {
        return NSError(domain: domain, code: self.rawValue, userInfo: [NSLocalizedDescriptionKey: self.description])
    }
}
