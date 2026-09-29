import Foundation

struct SettingItem<ViewModel: BaseViewModel>: Identifiable {
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
