import Foundation

enum OvertureEnvironment {
    #if targetEnvironment(simulator)
    static let apiBaseURL = URL(string: "http://localhost:3001")!
    #else
    static let apiBaseURL = URL(string: "https://maxw.news")!
    #endif
}
