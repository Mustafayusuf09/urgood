import SwiftUI

struct Chip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.footnote)
                .foregroundColor(isSelected ? .white : .brandPrimary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.xl)
                        .fill(isSelected ? Color.brandPrimary : Color.brandPrimary.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.xl)
                        .stroke(Color.brandPrimary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
    }
}

struct SelectableChip: View {
    let title: String
    @Binding var isSelected: Bool
    
    var body: some View {
        Chip(title: title, isSelected: isSelected) {
            isSelected.toggle()
        }
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        HStack(spacing: Spacing.sm) {
            Chip(title: "Default", isSelected: false) {}
            Chip(title: "Selected", isSelected: true) {}
        }
        
        HStack(spacing: Spacing.sm) {
            SelectableChip(title: "Exams", isSelected: .constant(false))
            SelectableChip(title: "Sleep", isSelected: .constant(true))
            SelectableChip(title: "Friends", isSelected: .constant(false))
        }
    }
    .padding()
    .themeEnvironment()
}
