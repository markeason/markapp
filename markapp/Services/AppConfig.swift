import Foundation

/// Provides access to configuration values defined in secrets.xcconfig
struct AppConfig {
    // MARK: - Supabase Configuration
    
    /// The Supabase URL from secrets.xcconfig
    static var supabaseURL: String {
        return getValueFromInfoPlist(for: "SUPABASE_URL")
    }
    
    /// The Supabase API key from secrets.xcconfig
    static var supabaseKey: String {
        return getValueFromInfoPlist(for: "SUPABASE_KEY")
    }
    
    // MARK: - OpenAI Configuration
    
    /// The OpenAI API key from secrets.xcconfig
    static var openAIAPIKey: String {
        return getValueFromInfoPlist(for: "OPENAI_API_KEY")
    }
    
    // MARK: - Private Helpers
    
    /// Retrieves a value from Info.plist
    /// - Parameter key: The key to retrieve
    /// - Returns: The value as a string or an empty string if not found
    private static func getValueFromInfoPlist(for key: String) -> String {
        guard let value = Bundle.main.infoDictionary?[key] as? String else {
            print("Warning: Value for \(key) not found in Info.plist")
            return ""
        }
        return value
    }
} 