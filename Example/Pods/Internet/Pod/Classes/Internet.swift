import ReachabilitySwift


public class InternetChange
{
    private let block: (Reachability.NetworkStatus) -> Void
    
    public init(block: (Reachability.NetworkStatus) -> Void)
    {
        self.block = block
    }
    
    public func run(status: Reachability.NetworkStatus)
    {
        self.block(status)
    }
}


private func -=(inout lhs: [InternetChange], rhs: InternetChange)
{
    var result: [InternetChange] = []
    for element in lhs {
        if element !== rhs {
            result.append(element)
        }
    }
    lhs = result
}


public class Internet
{
    internal static var reachability: Reachability!
    private static var blocks: [InternetChange] = []
    
    public static func start(hostName: String)
    {
        Internet.start(Reachability(hostname: hostName))
    }
    
    public static func start(reachability: Reachability)
    {
        Internet.reachability = reachability
        let statusBlock = { (reachability: Reachability) -> Void in
            let status = reachability.currentReachabilityStatus
            for block in Internet.blocks {
                block.run(status)
            }
        }
        Internet.reachability.whenReachable = statusBlock
        Internet.reachability.whenUnreachable = statusBlock
        Internet.reachability.startNotifier()
    }
    
    public static func start()
    {
        Internet.start(Reachability.reachabilityForInternetConnection())
    }
    
    public static func pause()
    {
        Internet.reachability.stopNotifier()
    }
    
    public static func addChangeBlock(block: (Reachability.NetworkStatus) -> Void) -> InternetChange
    {
        let result = InternetChange(block: block)
        Internet.blocks.append(result)
        return result
    }
    
    public static func removeChangeBlock(block: InternetChange)
    {
        Internet.blocks -= block
    }
    
    public static func areYouThere() -> Bool
    {
        return Internet.reachability.currentReachabilityStatus != .NotReachable
    }
}
