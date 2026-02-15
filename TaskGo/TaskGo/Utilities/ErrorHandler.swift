import SwiftUI

/// Centralized error handling for the app
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()

    @Published var currentError: AppError?
    @Published var showError = false

    private init() {}

    func handle(_ error: Error, context: String = "") {
        let appError = AppError(
            message: error.localizedDescription,
            context: context,
            timestamp: Date()
        )
        DispatchQueue.main.async {
            self.currentError = appError
            self.showError = true
        }

        // Log for debugging
        print("[TaskGo! Error] \(context): \(error.localizedDescription)")
    }

    func dismiss() {
        showError = false
        currentError = nil
    }
}

struct AppError: Identifiable {
    let id = UUID()
    let message: String
    let context: String
    let timestamp: Date

    var displayMessage: String {
        if context.isEmpty {
            return message
        }
        return "\(context): \(message)"
    }
}

/// Error banner view to show at the top of the popover
struct ErrorBannerView: View {
    @ObservedObject var errorHandler = ErrorHandler.shared

    var body: some View {
        if errorHandler.showError, let error = errorHandler.currentError {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white)

                Text(error.displayMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Spacer()

                Button(action: { errorHandler.dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                // Auto-dismiss after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation { errorHandler.dismiss() }
                }
            }
        }
    }
}
