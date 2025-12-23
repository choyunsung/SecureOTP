import SwiftUI

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "app_language")
        }
    }

    private init() {
        self.currentLanguage = UserDefaults.standard.string(forKey: "app_language") ?? "en"
    }

    func localizedString(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
}

// SwiftUI wrapper for localized strings
struct LocalizedText: View {
    let key: String
    @ObservedObject private var localizationManager = LocalizationManager.shared

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        Text(localizationManager.localizedString(key))
    }
}

// Helper extension
extension String {
    func localized() -> String {
        LocalizationManager.shared.localizedString(self)
    }
}
