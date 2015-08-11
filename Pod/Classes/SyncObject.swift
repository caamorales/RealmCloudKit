import MultiRealm
import RealmSwift


public class SyncObject: Object
{
    dynamic var uid = NSUUID().UUIDString
    
    override public class func primaryKey() -> String?
    {
        return "uid"
    }
}
