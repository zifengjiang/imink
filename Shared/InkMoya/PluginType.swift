import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol PluginType {
    func prepare(_ request: URLRequest, target: TargetType) -> URLRequest
    func willSend(_ request: URLRequest, target: TargetType)
    func didReceive(_ result: Result<(Data, HTTPURLResponse), Error>, target: TargetType)
}

public extension PluginType {
    func prepare(_ request: URLRequest, target: TargetType) -> URLRequest { request }
    func willSend(_ request: URLRequest, target: TargetType) {}
    func didReceive(_ result: Result<(Data, HTTPURLResponse), Error>, target: TargetType) {}
}
