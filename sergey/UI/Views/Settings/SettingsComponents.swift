import SwiftUI

struct SettingsSectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    let disabled: Bool

    init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>, disabled: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.disabled = disabled
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Toggle(isOn: $isOn) {}
                .toggleStyle(.switch)
                .disabled(disabled)
        }
        .padding(.vertical, 4)
    }
}

struct SettingsPickerRow<Label: View, SelectionValue: Hashable, Content: View>: View {
    let label: Label
    @Binding var selection: SelectionValue
    let disabled: Bool
    @ViewBuilder let content: () -> Content

    init(selection: Binding<SelectionValue>, disabled: Bool = false,
         @ViewBuilder label: () -> Label,
         @ViewBuilder content: @escaping () -> Content) {
        self._selection = selection
        self.disabled = disabled
        self.label = label()
        self.content = content
    }

    var body: some View {
        VStack(spacing: 4) {
            Picker(selection: $selection) {
                content()
            } label: {
                label
            }
            .disabled(disabled)
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}


struct SettingsTextFieldRow: View {
    let title: String
    let subtitle: String?
    let placeholder: String
    @Binding var text: String

    init(_ title: String, subtitle: String? = nil, placeholder: String, text: Binding<String>) {
        self.title = title
        self.subtitle = subtitle
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}


struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.vertical, 4)
    }
}


struct SettingsPageHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            trailing
        }
        .padding(24)
    }
}


struct SettingsPane<Trailing: View, Content: View>: View {
    let title: String
    @ViewBuilder let trailing: Trailing
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsPageHeader(title) { trailing }
            Divider()
            content
        }
    }
}


struct SettingsSplitPane<Left: View, Right: View>: View {
    let leftWidth: CGFloat
    @ViewBuilder let left: Left
    @ViewBuilder let right: Right

    init(leftWidth: CGFloat = 300, @ViewBuilder left: () -> Left, @ViewBuilder right: () -> Right) {
        self.leftWidth = leftWidth
        self.left = left()
        self.right = right()
    }

    var body: some View {
        HStack(spacing: 0) {
            left
                .frame(width: leftWidth)
            Divider()
                .padding(.vertical, 8)
            right
                .frame(minWidth: 400, maxWidth: .infinity)
        }
    }
}


struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}


struct SettingsSectionContainer<Content: View>: View {
    let header: SettingsSectionHeader?
    @ViewBuilder let content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.header = SettingsSectionHeader(title, subtitle: subtitle)
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let header = header {
                header
            }
            SettingsCard {
                content
            }
        }
    }
}
