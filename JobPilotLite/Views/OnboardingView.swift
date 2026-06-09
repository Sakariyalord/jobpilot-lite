import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @FocusState private var focusedField: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.t("JobPilot Lite"))
                            .font(.system(size: 36, weight: .bold))
                        Text(store.t("Build your job profile once, generate resumes from templates, match roles across industries, and track every follow-up."))
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)

                    QuickStartChoices(profile: $store.profile)

                    ProfileForm(profile: $store.profile, compact: true)

                    Button {
                        store.saveProfile()
                    } label: {
                        Label(store.t("Save Profile & Show Matches"), systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canContinue)

                    NavigationLink {
                        ResumeTemplateView()
                    } label: {
                        Label(store.t("Preview Resume"), systemImage: "doc.text.magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(!canContinue)

                    Button {
                        store.useDemoProfile()
                    } label: {
                        Text(store.t("Use Demo Profile"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(20)
            }
            .background(AppColor.groupedBackground)
        }
    }

    private var canContinue: Bool {
        !store.profile.fullName.isEmpty &&
        !store.profile.email.isEmpty &&
        !store.profile.targetTitle.isEmpty
    }
}

struct QuickStartChoices: View {
    @EnvironmentObject private var store: AppStore
    @Binding var profile: CandidateProfile

    private let roles = [
        "Operations Associate",
        "Customer Support",
        "Sales Representative",
        "Retail Associate",
        "Healthcare Coordinator",
        "Marketing Associate",
        "Data Analyst",
        "Software Engineer",
        "Finance Analyst",
        "HR Coordinator",
        "Warehouse Associate",
        "Teacher"
    ]
    private let locations = ["Remote", "New York", "Los Angeles", "Chicago", "Dallas", "San Francisco", "Toronto"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(store.t("Quick start"))
                .font(.headline)

            ChoiceRow(title: store.t("Target"), options: roles, selection: $profile.targetTitle)
            ChoiceRow(title: store.t("Location"), options: locations, selection: $profile.preferredLocation)
            WorkModeChoiceRow(selection: $profile.workModePreference)
            OpportunityTypeChoiceRow(selection: $profile.opportunityType)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ChoiceRow: View {
    @EnvironmentObject private var store: AppStore
    var title: String
    var options: [String]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            selection = option
                        } label: {
                            Text(store.t(option))
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selection == option ? Color.blue : AppColor.secondaryGroupedBackground)
                                .foregroundStyle(selection == option ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }
}

struct WorkModeChoiceRow: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selection: WorkModePreference

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.t("Work mode"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(WorkModePreference.allCases) { mode in
                        Button {
                            selection = mode
                        } label: {
                            Text(store.t(mode.rawValue))
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selection == mode ? Color.blue : AppColor.secondaryGroupedBackground)
                                .foregroundStyle(selection == mode ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }
}

struct OpportunityTypeChoiceRow: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selection: OpportunityType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.t("Opportunity type"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(OpportunityType.allCases) { type in
                        Button {
                            selection = type
                        } label: {
                            Text(store.t(type.rawValue))
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selection == type ? Color.blue : AppColor.secondaryGroupedBackground)
                                .foregroundStyle(selection == type ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }
}
