import Foundation

struct SettingSection<ViewModel: BaseViewModel>: Identifiable {
    let id: UUID = UUID()
    let title: String
    let settings: [SettingItem<ViewModel>]
}
