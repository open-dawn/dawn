import Foundation

struct SettingSection<ViewModel: AnyObject>: Identifiable {
    let id: UUID = UUID()
    let title: String
    let settings: [SettingItem<ViewModel>]
}
