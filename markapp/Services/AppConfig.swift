import Foundation

/// Provides access to configuration values defined in secrets.xcconfig
struct AppConfig {
    // MARK: - Constants
    
    // Your production Supabase URL - this is not a secret
    static let supabaseURL = "https://upqqdccrwrhzzjvmpumb.supabase.co"
    
    // MARK: - Helper Methods
    
    /// Helper to clean up configuration values by removing quotes and whitespace
    private static func cleanConfigValue(_ value: String) -> String {
        // Remove any surrounding quotes and whitespace
        var cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if surrounded by quotes and remove them
        if cleanValue.hasPrefix("\"") && cleanValue.hasSuffix("\"") && cleanValue.count >= 2 {
            let startIndex = cleanValue.index(after: cleanValue.startIndex)
            let endIndex = cleanValue.index(before: cleanValue.endIndex)
            cleanValue = String(cleanValue[startIndex..<endIndex])
        }
        
        return cleanValue
    }
    
    // MARK: - API Keys
    
    /// The Supabase API key from configuration
    static var supabaseKey: String {
        // First try Info.plist
        if let plistKey = Bundle.main.infoDictionary?["SUPABASE_KEY"] as? String {
            let cleanKey = cleanConfigValue(plistKey)
            if !cleanKey.isEmpty {
                return cleanKey
            }
        }
        
        // Then try environment variables
        if let envKey = ProcessInfo.processInfo.environment["SUPABASE_KEY"] {
            let cleanKey = cleanConfigValue(envKey)
            if !cleanKey.isEmpty {
                return cleanKey
            }
        }
        
        print("⚠️ AppConfig: SUPABASE_KEY not found")
        return ""
    }
    
    /// The OpenAI API key from configuration
    static var openAIAPIKey: String {
        // First try Info.plist
        if let plistKey = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String {
            let cleanKey = cleanConfigValue(plistKey)
            if !cleanKey.isEmpty {
                return cleanKey
            }
        }
        
        // Then try environment variables
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            let cleanKey = cleanConfigValue(envKey)
            if !cleanKey.isEmpty {
                return cleanKey
            }
        }
        
        print("⚠️ AppConfig: OPENAI_API_KEY not found")
        return ""
    }
    
    // MARK: - Development Helpers
    
    /// Helper function to check if all required API keys are set
    static func validateAPIKeys() {
        print("🔍 AppConfig: Validating API keys...")
        
        #if DEBUG
        print("✅ AppConfig: SUPABASE_URL is set: '\(supabaseURL)'")
        
        if supabaseKey.isEmpty {
            print("⚠️ AppConfig: SUPABASE_KEY is not set")
        } else {
            print("✅ AppConfig: SUPABASE_KEY is set (length: \(supabaseKey.count))")
        }
        
        if openAIAPIKey.isEmpty {
            print("⚠️ AppConfig: OPENAI_API_KEY is not set")
        } else {
            print("✅ AppConfig: OPENAI_API_KEY is set (length: \(openAIAPIKey.count))")
        }
        #endif
    }
} 