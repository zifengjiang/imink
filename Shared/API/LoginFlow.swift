import Foundation
import AuthenticationServices
import SwiftyJSON

class NSOAuthorization:NSObject,ASWebAuthenticationPresentationContextProviding {
    func login(sessionToken: (String)->Void) async throws{
        let codeVerifier = NSOHash.urandom(length: 32).base64EncodedString
        let authorizeAPI = NSOAPI.authorize(codeVerifier: codeVerifier)
        guard let sessionTokenCode = try await presentLoginSession(url: authorizeAPI.url)?.sessionTokenCode else {throw NSOAuthError.invalidCallbackURL}
        let sessionTokenAPI = NSOAPI.sessionToken(codeVerifier: codeVerifier, sessionTokenCode:sessionTokenCode)
        let (data, response) = try await URLSession.shared.data(for: sessionTokenAPI.request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSOAuthError.invalidSessionToken
        }
        let json = JSON(data)
        sessionToken(json["session_token"].stringValue)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if Thread.isMainThread {
            return ASPresentationAnchor()
        } else {
            var anchor: ASPresentationAnchor?
            DispatchQueue.main.sync {
                anchor = ASPresentationAnchor()
            }
            return anchor!
        }
    }

    func presentLoginSession(url: URL) async throws -> URL? {
        return try await withCheckedThrowingContinuation { continuation in
            let authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: "npf71b963c1b7b6d119") { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: callbackURL)
                }
            }
            authSession.presentationContextProvider = self
            authSession.start()
        }
    }

    enum NSOAuthError:Error{
        case invalidCallbackURL
        case invalidSessionToken
    }
}


extension URL {
    var sessionTokenCode: String? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        var combinedQuery = components.query ?? ""
        if let fragment = components.fragment {
            combinedQuery += "&" + fragment
        }

        guard let queryItems = URLComponents(string: "?" + combinedQuery)?.queryItems else { return nil }
        return queryItems.first(where: { $0.name == "session_token_code" })?.value
    }
}
