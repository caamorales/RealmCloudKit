import MultiRealm
import RealmSwift
import CloudKit
import CryptoSwift
import SwiftFileManager
import Backgroundable


public enum MergePolicy
{
    case Default
    case LocalFirst
    case ServerFirst
}


public final class RealmCloudKit
{
    public var realm: Realm {
        return self.backgroundRealm.realm
    }
    private let backgroundRealm: MultiRealm
    private var cloudKitRealm: MultiRealm!
    private func setupCloudKitRealm()
    {
        NSFileManager.URLForFile(.Database, withName: self.realm.path.lastPathComponent) { [unowned self] (success, finalURL) -> Void in
            if !success || !NSFileManager.excludeFileFromBackup(finalURL!) {
                NSException(name: NSInternalInconsistencyException, reason: "There was an error getting CloudKitRealm's path", userInfo: nil).raise()
            } else {
                toBackground { [unowned self] ()->() in
                    let keychain = Keychain(service: "com.bellapplab.RealmCloudKit")
                    var password = keychain.getData("RealmCloudKit")
                    if password == nil {
                        password = Cipher.randomIV(64)
                        keychain.set(password!, key: "RealmCloudKit")
                    }
                    self.cloudKitRealm = MultiRealm(path: finalURL!.path!, readOnly: false, encryptionKey: password!, queueType: .Background)
                }
            }
        }
    }
    
    public convenience init(realm: Realm) {
        self.init(path: realm.path, encryptionKey: nil)
    }
    
    public convenience init(path: String = Realm.defaultPath) {
        self.init(path: path, encryptionKey: nil)
    }
    
    public init(path: String, encryptionKey: NSData? = nil) {
        var error = NSErrorPointer()
        self.backgroundRealm = MultiRealm(path: path, readOnly: false, encryptionKey: encryptionKey, queueType: .Background)
        self.setupCloudKitRealm()
    }
}
