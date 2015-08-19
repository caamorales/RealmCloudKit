import Backgroundable
import CloudKit
import SwiftFileManager


internal func getCloudAccount(options: Options, deleteBlock: ((()->())?)->(), resultBlock: (Bool, NSError?)->Void)
{
    let cloudKitTokenKey = domain + ".ubiquityToken"
    let cloudKitPreferenceKey = domain + ".IPromiseTheUserWantsToUseiCloud"
    let defaults = NSUserDefaults.standardUserDefaults()
    
    let icloudBlock: ()->() = {
        let permissionBlock: ()->() = {
            //Ask for the user's permission
            options.container.accountStatusWithCompletionHandler { (status: CKAccountStatus, error: NSError!) -> Void in
                if status == .Available
                {//And start the database
                    resultBlock(true, nil)
                }
                else if status == .CouldNotDetermine
                {//An error occurred
                    resultBlock(false, error)
                }
                else
                {//iCloud is restricted by the system
                    //We don't really need to care about the .NoAccount case
                    resultBlock(false, RealmCloudKitError.Restricted.produceError())
                }
            }
        }
        
        if var systemToken = NSFileManager.defaultManager().ubiquityIdentityToken
        {//There's an iCloud account on the device
            if var token = defaults.objectForKey(cloudKitTokenKey) as? protocol<NSCoding, NSCopying, NSObjectProtocol>
            {//We have already set up CloudKit, but the user may still have changed
                if !token.isEqual(systemToken)
                {//Yep, it's changed
                    //So we delete the previous database and ask for the user's permission
                    deleteBlock(permissionBlock)
                }
            }
            else
            {//We haven't set up CloudKit
                //So we start it
                permissionBlock()
            }
            //We can store the system token in the Defaults
            defaults.setObject(systemToken, forKey: cloudKitTokenKey)
            defaults.synchronize()
        }
        else
        {//We don't have an iCloud account
            if var token = defaults.objectForKey(cloudKitTokenKey) as? protocol<NSCoding, NSCopying, NSObjectProtocol>
            {//The user disconnected from iCloud
                //So we delete the previous database
                deleteBlock(nil)
            }
            toMainThread {
                //And we ask for an account
                let alert = UIAlertController(title: NSLocalizedString("iCloudSetup", tableName: "RealmCloudKit", bundle: bundle, comment: "Title for the alert view that asks the user to log into iCloud"), message: NSLocalizedString("iCloudSetupDescription", tableName: "RealmCloudKit", bundle: bundle, comment: "Description for the alert view that asks the user to log into iCloud"), preferredStyle: .Alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("No", tableName: "RealmCloudKit", bundle: bundle, comment: ""), style: .Cancel, handler: { (action: UIAlertAction!) -> Void in
                    resultBlock(false, RealmCloudKitError.PasswordMiss.produceError())
                }))
                alert.addAction(UIAlertAction(title: NSLocalizedString("Yes", tableName: "RealmCloudKit", bundle: bundle, comment: ""), style: .Default, handler: { (action: UIAlertAction!) -> Void in
                    toMainThread {
                        UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
                    }
                }))
                if var window = UIApplication.sharedApplication().keyWindow {
                    if var viewController = window.rootViewController {
                        viewController.presentViewController(alert, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    if var theUserWantsToUseiCloud = defaults.objectForKey(cloudKitPreferenceKey) as? NSNumber
    {//We have asked the user
        if theUserWantsToUseiCloud.boolValue
        {//And they want to
            icloudBlock()
        }
        else
        {//And they said NO, or they had said yes, but changed their mind...
            deleteBlock({
                resultBlock(false, RealmCloudKitError.TurnedOff.produceError())
            })
        }
    }
    else
    {//We have never asked
        //So we ask
        let alert = UIAlertController(title: NSLocalizedString("iCloudPreference", tableName: "RealmCloudKit", bundle: bundle, comment: "Title for the alert view that asks the user if they want to use iCloud"), message: NSLocalizedString("iCloudPreferenceDescription", tableName: "RealmCloudKit", bundle: bundle, comment: "Description for the alert view that asks the user if they want to use iCloud"), preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("No", tableName: "RealmCloudKit", bundle: bundle, comment: ""), style: .Cancel, handler: { (action: UIAlertAction!) -> Void in
            defaults.setObject(NSNumber(bool: false), forKey: cloudKitPreferenceKey)
            defaults.synchronize()
            resultBlock(false, RealmCloudKitError.Denied.produceError())
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Yes", tableName: "RealmCloudKit", bundle: bundle, comment: ""), style: .Default, handler: { (action: UIAlertAction!) -> Void in
            defaults.setObject(NSNumber(bool: true), forKey: cloudKitPreferenceKey)
            defaults.synchronize()
            toBackground {
                icloudBlock()
            }
        }))
        if var window = UIApplication.sharedApplication().keyWindow {
            if var viewController = window.rootViewController {
                viewController.presentViewController(alert, animated: true, completion: nil)
            }
        }
    }
}
