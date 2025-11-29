import Foundation

struct LegalDocuments {
    static let privacyPolicyURL = "https://yourdomain.com/privacy" // REPLACE WITH YOUR URL
    static let termsOfServiceURL = "https://yourdomain.com/terms" // REPLACE WITH YOUR URL

    // Temporary embedded privacy policy until you host it
    static let privacyPolicy = """
    # Privacy Policy for Homi

    Last updated: \(Date().formatted(date: .long, time: .omitted))

    ## Information We Collect

    ### Information You Provide
    - Account information (name, email, profile photo)
    - House and roommate information
    - Expense and payment records
    - Messages between roommates
    - Task and chore assignments
    - Location data (when you share your location)

    ### Information Collected Automatically
    - Device information and identifiers
    - App usage analytics
    - Crash reports and performance data

    ## How We Use Your Information
    - To provide and maintain the Homi service
    - To enable expense splitting and payment tracking
    - To facilitate communication between roommates
    - To improve our services and develop new features
    - To send important notifications about your account

    ## Data Sharing
    We do not sell your personal information. We share your information only:
    - With your roommates (as part of the app's functionality)
    - With service providers who assist in operating our service
    - When required by law or to protect rights and safety

    ## Data Security
    We implement appropriate technical and organizational measures to protect your data, including:
    - Encryption of data in transit and at rest
    - Regular security audits
    - Access controls and authentication

    ## Data Retention
    - Active account data: Retained while your account is active
    - Deleted account data: Removed within 30 days of account deletion
    - Some data may be retained longer for legal or legitimate business purposes

    ## Your Rights
    You have the right to:
    - Access your personal data
    - Correct inaccurate data
    - Delete your account and associated data
    - Export your data
    - Opt-out of non-essential communications

    ## Children's Privacy
    Homi is not intended for users under 17 years of age. We do not knowingly collect data from children under 17.

    ## Changes to This Policy
    We may update this policy from time to time. We will notify you of any material changes via the app.

    ## Contact Us
    For privacy concerns or questions, contact us at: privacy@yourdomain.com
    """

    static let termsOfService = """
    # Terms of Service for Homi

    Last updated: \(Date().formatted(date: .long, time: .omitted))

    ## 1. Acceptance of Terms
    By using Homi, you agree to these Terms of Service. If you do not agree, do not use the app.

    ## 2. Description of Service
    Homi is a roommate management app that helps with:
    - Expense splitting and tracking
    - Chore and task management
    - Communication between housemates
    - Shared calendar and events

    ## 3. User Accounts
    - You must provide accurate information
    - You are responsible for maintaining account security
    - You must be at least 17 years old
    - One person per account

    ## 4. Acceptable Use
    You agree not to:
    - Use Homi for illegal purposes
    - Harass or harm other users
    - Impersonate others
    - Attempt to breach security
    - Spam or send unsolicited messages
    - Upload malicious code or content

    ## 5. Financial Tracking
    - Homi tracks but does not process actual payments
    - Users are responsible for settling debts outside the app
    - Expense records are for informational purposes only
    - We are not responsible for disputes between users

    ## 6. Privacy
    Your use of Homi is also governed by our Privacy Policy.

    ## 7. Intellectual Property
    - Homi and its content are owned by us
    - You retain rights to content you upload
    - You grant us license to use your content for service operation

    ## 8. Disclaimers
    - Homi is provided "as is" without warranties
    - We do not guarantee availability or accuracy
    - We are not liable for user disputes or financial losses

    ## 9. Limitation of Liability
    Our total liability is limited to $100 or the amount you paid us in the past 12 months, whichever is greater.

    ## 10. Termination
    - Either party may terminate at any time
    - We may suspend accounts for violations
    - Your obligations survive termination

    ## 11. Changes to Terms
    We may modify these terms. Continued use constitutes acceptance of new terms.

    ## 12. Governing Law
    These terms are governed by the laws of [YOUR STATE/COUNTRY].

    ## 13. Contact
    For questions about these terms, contact: legal@yourdomain.com
    """
}