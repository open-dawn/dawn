import Foundation

protocol BaseViewModel: AnyObject {
    var isLoading: Bool { get }
    var error: NSError? { get }
    var errorMessage: String? { get }
}
