import Foundation

enum SettingInputType<ViewModel> {
    case toggle(ReferenceWritableKeyPath<ViewModel, Bool>)
    case textField(ReferenceWritableKeyPath<ViewModel, String>)

    func getAssociatedValue(_ vm: ViewModel) -> Any {
        switch (self) {
            case .toggle(let keyPath): return vm[keyPath: keyPath]
            case .textField(let keyPath): return vm[keyPath: keyPath]
        }
    }

    func getKeyPath(_ vm: ViewModel) -> AnyKeyPath {
        switch (self) {
        case .toggle(let keyPath): return keyPath
        case .textField(let keyPath): return keyPath
        }
    }
}

struct SettingItem<ViewModel>: Identifiable {
    let id: UUID = UUID()
    let title: String
    let description: String
    let inputType: SettingInputType<ViewModel>
    let defaultValue: Any

    init(_ title: String, desc: String, type: SettingInputType<ViewModel>, defaultValue: Any) {
        self.title = title
        self.description = desc
        self.inputType = type
        self.defaultValue = defaultValue
    }
}

struct SettingSection<ViewModel>: Identifiable {
    let id: UUID = UUID()
    let title: String
    let settings: [SettingItem<ViewModel>]
}
