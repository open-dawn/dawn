import Foundation

protocol BaseViewModel: AnyObject {
    var isLoading: Bool { get }
    var error: ViewModelError? { get }
    var errorMessage: String? { get }
}
