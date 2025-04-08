import Foundation

/// Provides access to configuration values defined in secrets.xcconfig
struct AppConfig {
    // MARK: - Constants
    
    private static let fallbackSupabaseURL = "https://upqqdccrwrhzzjvmpumb.supabase.co"
    
    // MARK: - Supabase Configuration
    
    /// The Supabase URL from configuration
    static var supabaseURL: String {
        // Try environment first (from xcconfig)
        if let envUrl = ProcessInfo.processInfo.environment["SUPABASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !envUrl.isEmpty, envUrl != "https:" {
            print("📌 AppConfig: Using SUPABASE_URL from environment: '\(envUrl)'")
            return envUrl
        }
        
        // Try Info.plist
        if let plistUrl = (Bundle.main.infoDictionary?["SUPABASE_URL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !plistUrl.isEmpty, plistUrl != "https:" {
            print("📌 AppConfig: Using SUPABASE_URL from Info.plist: '\(plistUrl)'")
            return plistUrl
        }
        
        // Fallback to hardcoded URL
        print("⚠️ AppConfig: Using fallback Supabase URL")
        return fallbackSupabaseURL
    }
    
    /// The Supabase API key from configuration
    static var supabaseKey: String {
        // Try environment first (from xcconfig)
        if let envKey = ProcessInfo.processInfo.environment["SUPABASE_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !envKey.isEmpty {
            print("📌 AppConfig: Using SUPABASE_KEY from environment")
            return envKey
        }
        
        // Try Info.plist
        if let plistKey = (Bundle.main.infoDictionary?["SUPABASE_KEY"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !plistKey.isEmpty {
            print("📌 AppConfig: Using SUPABASE_KEY from Info.plist")
            return plistKey
        }
        
        print("⚠️ AppConfig: SUPABASE_KEY not found")
        return ""
    }
    
    // MARK: - OpenAI Configuration
    
    /// The OpenAI API key from configuration
    static var openAIAPIKey: String {
        // Try environment first (from xcconfig)
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !envKey.isEmpty {
            print("📌 AppConfig: Using OPENAI_API_KEY from environment")
            return envKey
        }
        
        // Try Info.plist
        if let plistKey = (Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !plistKey.isEmpty {
            print("📌 AppConfig: Using OPENAI_API_KEY from Info.plist")
            return plistKey
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