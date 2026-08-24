import Foundation

enum SettingInputType<ViewModel: BaseViewModel> {
    case toggle(ReferenceWritableKeyPath<ViewModel, Bool>)
    case textField(ReferenceWritableKeyPath<ViewModel, String>)

    func getAssociatedValue(_ viewModel: ViewModel) -> Any {
        return viewModel[keyPath: self.getKeyPath(viewModel)]
    }

    func getKeyPath(_ viewModel: ViewModel) -> AnyKeyPath {
        switch self {
        case .toggle(let keyPath): return keyPath
        case .textField(let keyPath): return keyPath
        }
    }
}
