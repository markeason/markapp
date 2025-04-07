import Foundation

/// Provides access to configuration values defined in secrets.xcconfig
struct AppConfig {
    // MARK: - Supabase Configuration
    
    /// The Supabase URL from secrets.xcconfig
    static var supabaseURL: String {
        var url = ""
        
        // Access directly from xcconfig via ProcessInfo
        if let envUrl = ProcessInfo.processInfo.environment["SUPABASE_URL"] {
            print("📌 AppConfig: Found SUPABASE_URL in environment: '\(envUrl)'")
            url = envUrl
        }
        // Second fallback: try Info.plist with the full URL key
        else if let plistUrl = Bundle.main.infoDictionary?["SUPABASE_URL_FULL"] as? String {
            print("📌 AppConfig: Found SUPABASE_URL_FULL in Info.plist: '\(plistUrl)'")
            url = plistUrl
        }
        // Third fallback: try original Info.plist key
        else if let plistUrl = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String {
            print("📌 AppConfig: Found SUPABASE_URL in Info.plist: '\(plistUrl)'")
            url = plistUrl
        }
        // Final manual fallback with hardcoded URL
        else {
            print("⚠️ AppConfig: SUPABASE_URL not found in environment or Info.plist - using manual fallback")
            url = "https://upqqdccrwrhzzjvmpumb.supabase.co"
            print("📌 AppConfig: Using hardcoded fallback URL: '\(url)'")
        }
        
        // Clean up the URL - trim whitespace
        let trimmedUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedUrl.isEmpty {
            print("❌ Warning: SUPABASE_URL is empty after trimming whitespace")
            return "https://upqqdccrwrhzzjvmpumb.supabase.co" // Emergency fallback
        }
        
        // In case of "https:" without host, fix it
        if trimmedUrl == "https:" {
            print("❌ AppConfig: Invalid URL format 'https:' detected - using manual fallback")
            return "https://upqqdccrwrhzzjvmpumb.supabase.co" // Emergency fallback
        }
        
        return trimmedUrl
    }
    
    /// The Supabase API key from secrets.xcconfig
    static var supabaseKey: String {
        var key = ""
        
        // Access directly from xcconfig via ProcessInfo
        if let envKey = ProcessInfo.processInfo.environment["SUPABASE_KEY"] {
            print("📌 AppConfig: Found SUPABASE_KEY in environment")
            key = envKey
        }
        // Second fallback: try Info.plist
        else if let plistKey = Bundle.main.infoDictionary?["SUPABASE_KEY"] as? String {
            print("📌 AppConfig: Found SUPABASE_KEY in Info.plist")
            key = plistKey
        }
        // Final fallback - empty string, with warning
        else {
            print("⚠️ AppConfig: SUPABASE_KEY not found in environment or Info.plist")
            return ""
        }
        
        // Clean up the key - trim whitespace
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedKey.isEmpty {
            print("Warning: SUPABASE_KEY is empty after trimming whitespace")
        }
        
        return trimmedKey
    }
    
    // MARK: - OpenAI Configuration
    
    /// The OpenAI API key from secrets.xcconfig
    static var openAIAPIKey: String {
        var key = ""
        
        // Access directly from xcconfig via ProcessInfo
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            print("📌 AppConfig: Found OPENAI_API_KEY in environment")
            key = envKey
        }
        // Second fallback: try Info.plist
        else if let plistKey = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String {
            print("📌 AppConfig: Found OPENAI_API_KEY in Info.plist")
            key = plistKey
        }
        // Final fallback - empty string, with warning
        else {
            print("⚠️ AppConfig: OPENAI_API_KEY not found in environment or Info.plist")
            return ""
        }
        
        // Clean up the key - trim whitespace
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedKey.isEmpty {
            print("Warning: OPENAI_API_KEY is empty after trimming whitespace")
        }
        
        return trimmedKey
    }
    
    // MARK: - Development Helpers
    
    /// Helper function to check if all required API keys are set
    static func validateAPIKeys() {
        print("🔍 AppConfig: Validating API keys...")
        
        #if DEBUG
        if supabaseURL.isEmpty {
            print("⚠️ AppConfig: SUPABASE_URL is not set")
        } else {
            print("✅ AppConfig: SUPABASE_URL is set: '\(supabaseURL)'")
        }
        
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