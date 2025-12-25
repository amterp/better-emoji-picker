//
//  SetupWizardView.swift
//  BetterEmojiPicker
//
//  First-run setup wizard for permissions and configuration.
//

import SwiftUI

/// The main setup wizard view that guides users through initial configuration.
struct SetupWizardView: View {

    @ObservedObject var viewModel: SetupViewModel
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            ProgressIndicator(currentStep: viewModel.currentStep)
                .padding(.top, 24)
                .padding(.bottom, 20)

            // Step content
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 32)

            // Navigation buttons
            navigationButtons
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
        }
        .frame(width: 500, height: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            viewModel.checkPermissions()
            viewModel.loadLaunchAtLoginState()
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .welcome:
            WelcomeStep()
        case .accessibility:
            AccessibilityStep(viewModel: viewModel)
        case .shortcut:
            ShortcutStep()
        case .launchAtLogin:
            LaunchAtLoginStep(viewModel: viewModel)
        case .complete:
            CompleteStep()
        }
    }

    private var navigationButtons: some View {
        HStack {
            if !viewModel.isFirstStep && !viewModel.isLastStep {
                Button("Back") {
                    viewModel.previousStep()
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if viewModel.isLastStep {
                Button("Get Started") {
                    viewModel.completeSetup()
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Continue") {
                    viewModel.nextStep()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canProceed)
            }
        }
    }
}

// MARK: - Progress Indicator

struct ProgressIndicator: View {
    let currentStep: SetupStep

    private let steps = SetupStep.allCases

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.element) { index, step in
                Circle()
                    .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Step Views

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "face.smiling")
                .font(.system(size: 64))
                .foregroundStyle(.linearGradient(
                    colors: [.yellow, .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Text("Welcome to Better Emoji Picker")
                .font(.title)
                .fontWeight(.semibold)

            Text("A fast, keyboard-driven emoji picker for macOS.\nPress **⌃⌘Space** anywhere to summon it.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .lineSpacing(4)

            Spacer()
        }
        .padding(.top, 20)
    }
}

struct AccessibilityStep: View {
    @ObservedObject var viewModel: SetupViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: viewModel.hasAccessibilityPermission ? "checkmark.shield.fill" : "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundColor(viewModel.hasAccessibilityPermission ? .green : .orange)

            Text("Accessibility Permission")
                .font(.title2)
                .fontWeight(.semibold)

            Text("BEP needs Accessibility permission to insert emojis into other apps. Without it, you can still copy emojis to clipboard.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .lineSpacing(4)

            // Permission status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.hasAccessibilityPermission ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(viewModel.hasAccessibilityPermission ? "Permission Granted" : "Permission Not Granted")
                    .font(.callout)
                    .foregroundColor(viewModel.hasAccessibilityPermission ? .green : .red)
            }
            .padding(.vertical, 4)

            if !viewModel.hasAccessibilityPermission {
                Button("Grant Permission") {
                    viewModel.requestAccessibilityPermission()
                }
                .buttonStyle(.bordered)

                Text("A system dialog will appear. Enable BEP in System Settings → Privacy & Security → Accessibility.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.top, 20)
    }
}

struct ShortcutStep: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "keyboard")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("Keyboard Shortcut")
                .font(.title2)
                .fontWeight(.semibold)

            Text("BEP uses **⌃⌘Space** (Control + Command + Space).\nThis may conflict with the system emoji picker.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 12) {
                Text("To disable the system shortcut:")
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("1.")
                            .fontWeight(.medium)
                            .frame(width: 20, alignment: .leading)
                        Text("Open **System Settings → Keyboard → Keyboard Shortcuts**")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("2.")
                            .fontWeight(.medium)
                            .frame(width: 20, alignment: .leading)
                        Text("Select **Input Sources** in the sidebar")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("3.")
                            .fontWeight(.medium)
                            .frame(width: 20, alignment: .leading)
                        Text("Uncheck or change the shortcut for **Select the previous input source**")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .font(.callout)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
            )

            Spacer()
        }
        .padding(.top, 20)
    }
}

struct LaunchAtLoginStep: View {
    @ObservedObject var viewModel: SetupViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "power")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("Launch at Login")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start BEP automatically when you log in so it's always ready.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Toggle(isOn: Binding(
                get: { viewModel.launchAtLoginEnabled },
                set: { _ in viewModel.toggleLaunchAtLogin() }
            )) {
                Text("Launch BEP at login")
            }
            .toggleStyle(.switch)
            .padding(.top, 8)

            Spacer()
        }
        .padding(.top, 20)
    }
}

struct CompleteStep: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("You're All Set!")
                .font(.title)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                Text("Remember:")
                    .fontWeight(.medium)

                HStack(spacing: 12) {
                    KeyboardShortcutBadge(keys: ["⌃", "⌘", "Space"])
                    Text("opens the emoji picker")
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    KeyboardShortcutBadge(keys: ["⌘", "C"])
                    Text("copies emoji to clipboard")
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    KeyboardShortcutBadge(keys: ["↵"])
                    Text("inserts emoji into active app")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
            )

            Spacer()
        }
        .padding(.top, 20)
    }
}

struct KeyboardShortcutBadge: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                    )
            }
        }
    }
}

#Preview {
    SetupWizardView(viewModel: SetupViewModel()) { }
}
