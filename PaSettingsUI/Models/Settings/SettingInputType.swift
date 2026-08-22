import Foundation

enum SettingInputType<ViewModel: BaseViewModel> {
    case toggle(ReferenceWritableKeyPath<ViewModel, Bool>)
    case textField(ReferenceWritableKeyPath<ViewModel, String>)

    func getAssociatedValue(_ vm: ViewModel) -> Any {
        return vm[keyPath: self.getKeyPath(vm)]
    }

    func getKeyPath(_ vm: ViewModel) -> AnyKeyPath {
        switch (self) {
            case .toggle(let keyPath): return keyPath
            case .textField(let keyPath): return keyPath
        }
    }
}
