import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ProfileForm(profile: $store.profile, compact: false)
                    MarketReadinessCard()

                    Button {
                        store.saveProfile()
                    } label: {
                        Label(store.t("Save Profile"), systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    AnalyticsSummaryView()

                    VStack(spacing: 0) {
                        ShareLink(item: "Try JobPilot Lite: a fast job application tracker for matching roles, templates, and follow-ups.") {
                            SettingsActionRow(icon: "square.and.arrow.up", title: store.t("Invite Test Users"), subtitle: store.t("Share the MVP with your first cohort"))
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            store.log(.shareOpened)
                        })

                        Divider().padding(.leading, 54)

                        Button {
                            openFeedback()
                        } label: {
                            SettingsActionRow(icon: "envelope", title: store.t("Send Feedback"), subtitle: store.t("Open an email with device and app context"))
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 54)

                        NavigationLink {
                            PrivacyPolicyView()
                        } label: {
                            SettingsActionRow(icon: "hand.raised", title: store.t("Privacy"), subtitle: store.t("Local MVP data and user control"))
                        }

                        Divider().padding(.leading, 54)

                        NavigationLink {
                            ResumeTemplateView()
                        } label: {
                            SettingsActionRow(icon: "doc.text", title: store.t("Resume Builder"), subtitle: store.t("Choose a format, generate, and copy your resume"))
                        }

                        Divider().padding(.leading, 54)

                        Button(role: .destructive) {
                            showResetConfirm = true
                        } label: {
                            SettingsActionRow(icon: "arrow.counterclockwise", title: store.t("Reset Local Data"), subtitle: store.t("Clear profile, tracker, and local metrics"))
                        }
                        .buttonStyle(.plain)
                    }
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(16)
            }
            .background(AppColor.groupedBackground)
            .navigationTitle(store.t("Profile"))
            .toolbar {
                ToolbarItem(placement: AppToolbarPlacement.trailing) {
                    NavigationLink {
                        AppSettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel(store.t("Settings"))
                }
            }
            .confirmationDialog(store.t("Reset all local MVP data?"), isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button(store.t("Reset"), role: .destructive) {
                    store.resetLocalData()
                }
                Button(store.t("Cancel"), role: .cancel) {}
            }
        }
    }

    private func openFeedback() {
        store.log(.feedbackOpened)
        let subject = "JobPilot Lite Feedback"
        let body = """
        What I tried:

        What felt useful:

        What blocked me:

        User target role: \(store.profile.targetTitle)
        Saved applications: \(store.applications.count)
        """

        guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "mailto:support@jobpilotlite.app?subject=\(encodedSubject)&body=\(encodedBody)") else {
            return
        }

        PlatformActions.open(url)
    }
}

struct ProfileForm: View {
    @EnvironmentObject private var store: AppStore
    @Binding var profile: CandidateProfile
    var compact: Bool

    private var skillsText: Binding<String> {
        Binding(
            get: { profile.skills.joined(separator: ", ") },
            set: {
                profile.skills = $0
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    private var targetCountrySelection: Binding<TargetCountry> {
        Binding(
            get: { profile.targetCountry },
            set: { newCountry in
                profile.targetCountry = newCountry
                profile.resumeRegion = newCountry.region
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(store.t("Essential profile"))
                .font(.headline)

            Text(store.t("Only the fields needed for matching and automatic job-specific resumes."))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(store.t("Basic information"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            TextField(store.t("Full name"), text: $profile.fullName)
                .fieldStyle()

            TextField(store.t("Email"), text: $profile.email)
                .fieldStyle()

            TextField(store.t("Phone"), text: $profile.phone)
                .fieldStyle()

            TextField(store.t("Current city"), text: $profile.city)
                .fieldStyle()

            Text(store.t("Target"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            TextField(store.t("Target role"), text: $profile.targetTitle)
                .fieldStyle()

            HStack {
                Label(store.t("Opportunity type"), systemImage: "briefcase")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Picker(store.t("Opportunity type"), selection: $profile.opportunityType) {
                    ForEach(OpportunityType.allCases) { type in
                        Text(store.t(type.rawValue)).tag(type)
                    }
                }
                .pickerStyle(.menu)
            }
            .fieldStyle()

            HStack(spacing: 10) {
                TextField(store.t("Preferred city or region"), text: $profile.preferredLocation)
                    .fieldStyle()

                Picker(store.t("Work mode"), selection: $profile.workModePreference) {
                    ForEach(WorkModePreference.allCases) { mode in
                        Text(store.t(mode.rawValue)).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 150)
                .padding(.horizontal, 10)
                .frame(height: 48)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Label(store.t("Target country"), systemImage: "map")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Picker(store.t("Target country"), selection: targetCountrySelection) {
                    ForEach(TargetCountry.allCases) { country in
                        Text(store.t(country.rawValue)).tag(country)
                    }
                }
                .pickerStyle(.menu)
            }
            .fieldStyle()

            Text(store.t("Education and skills"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            TextField(store.t("Education"), text: $profile.education, axis: .vertical)
                .lineLimit(2...4)
                .fieldStyle()

            TextField(store.t("Skills, separated by commas"), text: skillsText)
                .fieldStyle()

            Picker(store.t("Work authorization"), selection: $profile.workAuthorizationStatus) {
                ForEach(WorkAuthorizationStatus.allCases) { status in
                    Text(store.t(status.rawValue)).tag(status)
                }
            }
            .pickerStyle(.menu)
            .fieldStyle()

            TextField(store.t("Languages"), text: $profile.languages)
                .fieldStyle()
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ResumeTemplatePicker: View {
    @EnvironmentObject private var store: AppStore
    @Binding var profile: CandidateProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.t("Resume format"))
                .font(.headline)

            Text(store.t("Pick the resume layout that best fits the role you are applying to."))
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ResumeTemplate.allCases) { template in
                        Button {
                            profile.resumeTemplate = template
                        } label: {
                            ResumeTemplateOption(
                                template: template,
                                isSelected: profile.resumeTemplate == template
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ResumeTemplateOption: View {
    @EnvironmentObject private var store: AppStore
    var template: ResumeTemplate
    var isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: template.systemImage)
                    .font(.body.weight(.semibold))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body.weight(.semibold))
                }
            }

            Text(store.t(template.title))
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(store.t(template.subtitle))
                .font(.caption)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
        }
        .foregroundStyle(isSelected ? .white : .primary)
        .padding(12)
        .frame(width: 168, height: 126, alignment: .topLeading)
        .background(isSelected ? Color.blue : AppColor.secondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

extension View {
    func fieldStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct AnalyticsSummaryView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        let health = store.jobSearchHealth

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(store.t("Job Search Score"))
                    .font(.headline)
                Spacer()
                Text("\(health.score)")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.blue)
            }

            HStack(spacing: 10) {
                MetricTile(title: store.t("Profile"), value: "\(health.profileScore)")
                MetricTile(title: store.t("Pipeline"), value: "\(health.pipelineScore)")
                MetricTile(title: store.t("Matches"), value: "\(health.matchScore)")
            }

            Text(store.t("Improve the score by completing your profile, applying to strong matches, and clearing follow-ups."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct MarketReadinessCard: View {
    @EnvironmentObject private var store: AppStore
    @State private var copyMessage = ""

    var body: some View {
        let plan = store.marketReadinessPlan()

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 46, height: 46)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.t("Overseas job assistant"))
                        .font(.headline)
                    Text(plan.marketTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                    Text(plan.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let firstAction = plan.nextActions.first {
                VStack(alignment: .leading, spacing: 4) {
                    Label(store.t("Do this first"), systemImage: "arrow.forward.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(firstAction)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.secondaryGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(spacing: 10) {
                Button {
                    _ = store.saveMarketResumeVersion()
                    copyMessage = store.t("Market resume saved")
                } label: {
                    Label(store.t("Save market resume"), systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                HStack(spacing: 10) {
                    Button {
                        PlatformActions.copy(store.workRightsResumeLine())
                        copyMessage = store.t("Copied work-rights line")
                    } label: {
                        Label(store.t("Copy work-rights line"), systemImage: "person.badge.key")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        copyResumeFixes(plan)
                    } label: {
                        Label(store.t("Copy resume fixes"), systemImage: "checklist")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .controlSize(.large)

            MarketChecklistSection(
                title: store.t("Helpful next steps"),
                icon: "checklist.checked",
                rows: Array(plan.nextActions.dropFirst())
            )

            MarketChecklistSection(
                title: store.t("Fix before applying"),
                icon: "exclamationmark.circle",
                rows: plan.priorityGaps
            )

            MarketChecklistSection(
                title: store.t("Country-specific checks"),
                icon: "map",
                rows: plan.countryRules + plan.authorizationChecks
            )

            Button {
                copyMarketPlan(plan)
            } label: {
                Label(store.t("Copy market checklist"), systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            if !copyMessage.isEmpty {
                Label(copyMessage, systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func copyMarketPlan(_ plan: MarketReadinessPlan) {
        let text = """
        \(store.t("Overseas job assistant"))
        \(store.t("Target market")): \(plan.marketTitle)
        \(plan.summary)

        \(store.t("Helpful next steps"))
        \(plan.nextActions.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

        \(store.t("Fix before applying"))
        \(plan.priorityGaps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

        \(store.t("Country-specific checks"))
        \(plan.countryRules.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

        \(store.t("Resume rules"))
        \(plan.resumeRules.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

        \(store.t("Work authorization checks"))
        \(plan.authorizationChecks.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        """

        PlatformActions.copy(text)
        copyMessage = store.t("Copied market checklist")
    }

    private func copyResumeFixes(_ plan: MarketReadinessPlan) {
        let text = """
        \(store.t("Fix before applying")) - \(plan.marketTitle)
        \(plan.priorityGaps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

        \(store.t("Resume rules"))
        \(plan.resumeRules.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        """
        PlatformActions.copy(text)
        copyMessage = store.t("Copied resume fixes")
    }
}

struct MarketChecklistSection: View {
    var title: String
    var icon: String
    var rows: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption2.weight(.bold))
                            .frame(width: 18, height: 18)
                            .background(Color.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .clipShape(Circle())
                        Text(row)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MetricTile: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.secondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SettingsActionRow: View {
    var icon: String
    var title: String
    var subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .contentShape(Rectangle())
    }
}

struct AppSettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AccountSecurityCenterView()
                } label: {
                    SettingsCenterRow(
                        icon: "person.badge.shield.checkmark",
                        title: store.t("Account & Security Center"),
                        subtitle: store.profile.email.isEmpty ? store.t("Profile identity, privacy, and login controls") : store.profile.email
                    )
                }

                NavigationLink {
                    NotificationReminderSettingsView()
                } label: {
                    SettingsCenterRow(
                        icon: "bell.badge",
                        title: store.t("Notifications & Reminders"),
                        subtitle: store.t("Matches, follow-ups, interviews, and security alerts")
                    )
                }

                NavigationLink {
                    GeneralSettingsView()
                } label: {
                    SettingsCenterRow(
                        icon: "slider.horizontal.3",
                        title: store.t("General Settings"),
                        subtitle: "\(store.t("Language")): \(store.t(store.settings.language.rawValue))"
                    )
                }

                NavigationLink {
                    MessageSettingsView()
                } label: {
                    SettingsCenterRow(
                        icon: "message.badge",
                        title: store.t("Message Settings"),
                        subtitle: store.t("Tone, draft behavior, and message content")
                    )
                }
            }

            Section(store.t("Language")) {
                Picker(store.t("App language"), selection: $store.settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text("\(store.t(language.rawValue)) / \(language.nativeName)")
                            .tag(language)
                    }
                }
                .pickerStyle(.navigationLink)

                Text(store.t("English is the default language for this MVP. The selected language is saved locally and updates the app interface immediately."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(store.t("Settings"))
        .inlineNavigationTitle()
    }
}

struct AccountSecurityCenterView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Form {
            Section(store.t("Account")) {
                LabeledContent(store.t("Name"), value: store.profile.fullName.isEmpty ? store.t("Not set") : store.profile.fullName)
                LabeledContent(store.t("Email"), value: store.profile.email.isEmpty ? store.t("Not set") : store.profile.email)
                LabeledContent(store.t("Phone"), value: store.profile.phone.isEmpty ? store.t("Not set") : store.profile.phone)
            }

            Section(store.t("Security")) {
                Toggle(store.t("Biometric unlock"), isOn: $store.settings.biometricUnlock)
                Toggle(store.t("Hide personal data previews"), isOn: $store.settings.hidePersonalData)
                Toggle(store.t("Security alerts"), isOn: $store.settings.securityAlerts)
            }

            Section {
                SettingsNote(text: store.t("Password login, two-factor authentication, and account deletion should be connected when the real account backend is added."))
            }
        }
        .navigationTitle(store.t("Account & Security"))
        .inlineNavigationTitle()
    }
}

struct NotificationReminderSettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Form {
            Section(store.t("Notifications")) {
                Toggle(store.t("Daily match digest"), isOn: $store.settings.dailyMatchDigest)
                Toggle(store.t("Security alerts"), isOn: $store.settings.securityAlerts)
            }

            Section(store.t("Reminders")) {
                Toggle(store.t("Follow-up reminders"), isOn: $store.settings.followUpReminders)
                Toggle(store.t("Interview reminders"), isOn: $store.settings.interviewReminders)
            }

            Section {
                SettingsNote(text: store.t("These switches are stored locally now. Push notification permissions and scheduling can be connected after the MVP validates demand."))
            }
        }
        .navigationTitle(store.t("Notifications"))
        .inlineNavigationTitle()
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Form {
            Section(store.t("Language")) {
                Picker(store.t("Language"), selection: $store.settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text("\(store.t(language.rawValue)) / \(language.nativeName)")
                            .tag(language)
                    }
                }
            }

            Section(store.t("Experience")) {
                Toggle(store.t("Compact job cards"), isOn: $store.settings.compactJobCards)
                Toggle(store.t("Open apply links externally"), isOn: $store.settings.openApplyLinksExternally)
            }

            Section {
                SettingsNote(text: store.t("Default language is English. The selected app language updates supported interface strings immediately."))
            }
        }
        .navigationTitle(store.t("General"))
        .inlineNavigationTitle()
    }
}

struct MessageSettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Form {
            Section(store.t("Drafts")) {
                Toggle(store.t("Auto-save message drafts"), isOn: $store.settings.autoSaveDrafts)
                Toggle(store.t("Include resume summary"), isOn: $store.settings.includeResumeSummary)
                Toggle(store.t("Include contact info"), isOn: $store.settings.includeContactInfo)
            }

            Section(store.t("Tone")) {
                Picker(store.t("Message tone"), selection: $store.settings.messageTone) {
                    ForEach(MessageTone.allCases) { tone in
                        Text(store.t(tone.rawValue)).tag(tone)
                    }
                }
            }

            Section {
                SettingsNote(text: store.t("Message generation is template-based in this MVP, so these preferences prepare the product for safer personalization without adding AI API cost yet."))
            }
        }
        .navigationTitle(store.t("Messages"))
        .inlineNavigationTitle()
    }
}

struct SettingsCenterRow: View {
    var icon: String
    var title: String
    var subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SettingsNote: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PrivacyPolicyView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(store.t("Privacy"))
                    .font(.system(size: 32, weight: .bold))

                PrivacyBlock(title: store.t("Local MVP storage"), text: store.t("This prototype stores your profile, saved applications, follow-up dates, and local usage counters on this device."))
                PrivacyBlock(title: store.t("No AI processing"), text: store.t("The current version uses templates and local matching rules. It does not send resume content to an AI API."))
                PrivacyBlock(title: store.t("No automatic submission"), text: store.t("Application materials are generated for review. You choose whether to copy, email, or open an apply link."))
                PrivacyBlock(title: store.t("User control"), text: store.t("You can reset local profile, tracker, and metric data from the Profile tab."))
                PrivacyBlock(title: store.t("Before public launch"), text: store.t("Replace this MVP text with a lawyer-reviewed privacy policy, support address, data deletion path, and App Store privacy details."))
            }
            .padding(18)
        }
        .background(AppColor.groupedBackground)
        .navigationTitle(store.t("Privacy"))
        .inlineNavigationTitle()
    }
}

struct PrivacyBlock: View {
    var title: String
    var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(text)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColor.secondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ResumeTemplateView: View {
    @EnvironmentObject private var store: AppStore
    @State private var resumeText = ""
    @State private var targetJobTitle = ""
    @State private var targetCompany = ""
    @State private var jobDescription = ""
    @State private var versionName = ""
    @State private var audit = ATSResumeAudit.empty
    @State private var exportFiles: [ResumeExportFile] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ResumeTemplatePicker(profile: $store.profile)
                ResumeRegionCard(profile: $store.profile)
                ResumeTailoringCard(
                    targetJobTitle: $targetJobTitle,
                    targetCompany: $targetCompany,
                    jobDescription: $jobDescription,
                    generateAction: generateResume,
                    rewriteAction: rewriteResume
                )

                ATSScoreCard(audit: audit)

                TextEditor(text: $resumeText)
                    .font(.system(.footnote, design: .monospaced))
                    .padding(10)
                    .frame(minHeight: 420)
                    .background(AppColor.secondaryGroupedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: resumeText) { _, newValue in
                        audit = store.analyzeResumeText(
                            newValue,
                            targetJobTitle: targetJobTitle,
                            jobDescription: jobDescription
                        )
                        exportFiles = []
                    }

                ResumeActionPanel(
                    versionName: $versionName,
                    exportFiles: exportFiles,
                    saveAction: saveVersion,
                    copyAction: copyResume,
                    exportAction: buildExports
                )

                ResumeVersionLibrary(
                    versions: store.resumeVersions,
                    loadAction: loadVersion,
                    deleteAction: store.deleteResumeVersion
                )
            }
            .padding(16)
        }
        .background(AppColor.groupedBackground)
        .navigationTitle(store.t("Resume Studio"))
        .inlineNavigationTitle()
        .onAppear {
            generateResume()
        }
        .onChange(of: store.profile) { _, _ in
            generateResume()
        }
    }

    private func generateResume() {
        store.saveProfile()
        resumeText = store.generateResumeText(
            template: store.profile.resumeTemplate,
            region: store.profile.resumeRegion,
            targetJobTitle: targetJobTitle,
            company: targetCompany,
            jobDescription: jobDescription
        )
        audit = store.analyzeResumeText(
            resumeText,
            targetJobTitle: targetJobTitle,
            jobDescription: jobDescription
        )
        if versionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            versionName = "\(currentTargetTitle) - \(store.profile.resumeRegion.shortTitle)"
        }
        exportFiles = []
        store.log(.resumeGenerated, metadata: ["target_title": currentTargetTitle, "region": store.profile.resumeRegion.rawValue])
    }

    private func rewriteResume() {
        resumeText = store.rewriteResumeDraft(
            resumeText,
            targetJobTitle: targetJobTitle,
            jobDescription: jobDescription
        )
        audit = store.analyzeResumeText(
            resumeText,
            targetJobTitle: targetJobTitle,
            jobDescription: jobDescription
        )
        exportFiles = []
    }

    private func saveVersion() {
        store.saveResumeVersion(
            name: versionName,
            text: resumeText,
            template: store.profile.resumeTemplate,
            region: store.profile.resumeRegion,
            targetTitle: currentTargetTitle,
            company: targetCompany,
            atsScore: audit.score
        )
    }

    private func copyResume() {
        PlatformActions.copy(resumeText)
        store.log(.resumeCopied)
    }

    private func buildExports() {
        exportFiles = PlatformActions.writeResumeExports(text: resumeText, title: exportTitle)
        store.log(.resumeExported, metadata: ["formats": exportFiles.map(\.format.rawValue).joined(separator: ",")])
    }

    private func loadVersion(_ version: ResumeVersion) {
        resumeText = store.selectResumeVersion(version)
        targetJobTitle = version.targetTitle
        targetCompany = version.company
        versionName = version.name
        audit = store.analyzeResumeText(resumeText, targetJobTitle: targetJobTitle, jobDescription: jobDescription)
        exportFiles = []
    }

    private var currentTargetTitle: String {
        let trimmed = targetJobTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? store.profile.targetTitle : trimmed
    }

    private var exportTitle: String {
        let name = store.profile.fullName.isEmpty ? "Resume" : store.profile.fullName
        return "\(name) - \(currentTargetTitle)"
    }
}

struct ResumeRegionCard: View {
    @EnvironmentObject private var store: AppStore
    @Binding var profile: CandidateProfile

    private var resumeRegionSelection: Binding<ResumeRegion> {
        Binding(
            get: { profile.resumeRegion },
            set: { newRegion in
                profile.resumeRegion = newRegion
                if profile.targetCountry.region != newRegion {
                    profile.targetCountry = newRegion.defaultTargetCountry
                }
            }
        )
    }

    private var targetCountrySelection: Binding<TargetCountry> {
        Binding(
            get: { profile.targetCountry },
            set: { newCountry in
                profile.targetCountry = newCountry
                profile.resumeRegion = newCountry.region
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.t("Target market"))
                .font(.headline)

            Picker(store.t("Target market"), selection: resumeRegionSelection) {
                ForEach(ResumeRegion.allCases) { region in
                    Text(store.t(region.shortTitle)).tag(region)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Label(store.t("Target country"), systemImage: "map")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Picker(store.t("Target country"), selection: targetCountrySelection) {
                    ForEach(TargetCountry.allCases) { country in
                        Text(store.t(country.rawValue)).tag(country)
                    }
                }
                .pickerStyle(.menu)
            }
            .fieldStyle()

            Text(store.t(profile.resumeRegion.guidance))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ResumeTailoringCard: View {
    @EnvironmentObject private var store: AppStore
    @Binding var targetJobTitle: String
    @Binding var targetCompany: String
    @Binding var jobDescription: String
    var generateAction: () -> Void
    var rewriteAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.t("Job-tailored resume"))
                .font(.headline)

            TextField(store.t("Target job title"), text: $targetJobTitle)
                .fieldStyle()

            TextField(store.t("Company, optional"), text: $targetCompany)
                .fieldStyle()

            TextEditor(text: $jobDescription)
                .frame(minHeight: 128)
                .padding(8)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    if jobDescription.isEmpty {
                        Text(store.t("Paste job description for keyword targeting"))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 16)
                            .padding(.leading, 14)
                    }
                }

            HStack(spacing: 10) {
                Button(action: generateAction) {
                    Label(store.t("Generate"), systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: rewriteAction) {
                    Label(store.t("Rewrite"), systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ATSScoreCard: View {
    @EnvironmentObject private var store: AppStore
    var audit: ATSResumeAudit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(store.t("ATS score"))
                    .font(.headline)
                Spacer()
                Text("\(audit.score)")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(scoreColor)
            }

            HStack(spacing: 10) {
                MetricTile(title: store.t("Keywords"), value: "\(audit.keywordCoverage)%")
                MetricTile(title: store.t("Words"), value: "\(audit.wordCount)")
            }

            if !audit.missingKeywords.isEmpty {
                FlowTags(tags: audit.missingKeywords.map { "\(store.t("Missing")): \($0)" })
            }

            ForEach(audit.strengths, id: \.self) { strength in
                Label(store.t(strength), systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            ForEach(audit.warnings, id: \.self) { warning in
                Label(store.t(warning), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var scoreColor: Color {
        switch audit.score {
        case 80...100: return .green
        case 60..<80: return .blue
        default: return .orange
        }
    }
}

struct ResumeActionPanel: View {
    @EnvironmentObject private var store: AppStore
    @Binding var versionName: String
    var exportFiles: [ResumeExportFile]
    var saveAction: () -> Void
    var copyAction: () -> Void
    var exportAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(store.t("Version name"), text: $versionName)
                .fieldStyle()

            HStack(spacing: 10) {
                Button(action: saveAction) {
                    Label(store.t("Save"), systemImage: "tray.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: copyAction) {
                    Label(store.t("Copy"), systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)

            Button(action: exportAction) {
                Label(store.t("Build Export Files"), systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if !exportFiles.isEmpty {
                HStack(spacing: 10) {
                    ForEach(exportFiles) { file in
                        ShareLink(item: file.url) {
                            Label(file.format.rawValue, systemImage: file.format.systemImage)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ResumeVersionLibrary: View {
    @EnvironmentObject private var store: AppStore
    var versions: [ResumeVersion]
    var loadAction: (ResumeVersion) -> Void
    var deleteAction: (ResumeVersion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.t("Saved versions"))
                .font(.headline)

            if versions.isEmpty {
                Text(store.t("Saved resume versions will appear here."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(versions.prefix(8))) { version in
                    HStack(spacing: 12) {
                        Button {
                            loadAction(version)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(version.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("\(version.targetTitle) | \(store.t(version.region.shortTitle)) | \(store.t("ATS")) \(version.atsScore)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        Button(role: .destructive) {
                            deleteAction(version)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(12)
                    .background(AppColor.secondaryGroupedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
