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
}

struct SettingItem<ViewModel>: Identifiable {
    let id: UUID = UUID()
    let title: String
    let description: String
    let inputType: SettingInputType<ViewModel>

    init(_ title: String, desc: String, type: SettingInputType<ViewModel>) {
        self.title = title
        self.description = desc
        self.inputType = type
    }
}

struct SettingSection<ViewModel>: Identifiable {
    let id: UUID = UUID()
    let title: String
    let settings: [SettingItem<ViewModel>]
}
