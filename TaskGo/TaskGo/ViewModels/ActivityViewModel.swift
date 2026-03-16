import Foundation
import FirebaseAuth
import Combine

class ActivityViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var currentDay: ActivityDay?
    @Published var zoomLevel: Double = 60   // bucket size in minutes: 1, 5, 15, 30, 60
    @Published var visibleSeries: Set<DataSeries> = Set(DataSeries.allCases)
    @Published var chartData: [ChartDataPoint] = []
    @Published var isLoading = false

    static let zoomSteps: [Double] = [1, 5, 15, 30, 60]

    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?

    init() {
        Publishers.CombineLatest3($currentDay, $zoomLevel, $visibleSeries)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] day, zoom, series in
                self?.recomputeChartData(day: day, zoom: zoom, series: series)
            }
            .store(in: &cancellables)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var snappedZoomLevel: Double {
        Self.zoomSteps.min(by: { abs($0 - zoomLevel) < abs($1 - zoomLevel) }) ?? 60
    }

    var zoomLabel: String {
        let snapped = Int(snappedZoomLevel)
        if snapped >= 60 { return "1 hour" }
        return "\(snapped) min"
    }

    // MARK: - Data Loading

    func loadSelectedDate() {
        let date = selectedDate
        if isToday {
            currentDay = ActivityTracker.shared.todayData
            startLiveRefresh()
            return
        }

        stopLiveRefresh()
        isLoading = true

        if let local = ActivityTracker.shared.loadDay(date: date) {
            currentDay = local
            isLoading = false
            return
        }

        guard let userId = Auth.auth().currentUser?.uid else {
            currentDay = nil
            isLoading = false
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        Task { @MainActor in
            do {
                let day = try await FirestoreService.shared.getActivityDay(userId: userId, dateString: dateString)
                self.currentDay = day
            } catch {
                print("[ActivityVM] Failed to load day: \(error)")
                self.currentDay = nil
            }
            self.isLoading = false
        }
    }

    func goToPreviousDay() {
        guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        selectedDate = prev
        loadSelectedDate()
    }

    func goToNextDay() {
        guard !isToday else { return }
        guard let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        selectedDate = next
        loadSelectedDate()
    }

    func goToToday() {
        selectedDate = Date()
        loadSelectedDate()
    }

    // MARK: - Live Refresh

    private func startLiveRefresh() {
        stopLiveRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self, self.isToday else { return }
            self.currentDay = ActivityTracker.shared.todayData
        }
    }

    private func stopLiveRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Chart Data Computation

    private func recomputeChartData(day: ActivityDay?, zoom: Double, series: Set<DataSeries>) {
        guard let day = day else {
            chartData = []
            return
        }

        let bucketSize = Int(snappedZoomLevel)
        let totalBuckets = 1440 / bucketSize

        var points: [ChartDataPoint] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day.date)

        for bucket in 0..<totalBuckets {
            let bucketStart = bucket * bucketSize
            let bucketEnd = bucketStart + bucketSize

            let entriesInBucket = day.minuteData.filter { $0.minute >= bucketStart && $0.minute < bucketEnd }

            let labelDate = calendar.date(byAdding: .minute, value: bucketStart, to: startOfDay) ?? startOfDay
            let label = formatter.string(from: labelDate)

            for s in series.sorted(by: { $0.rawValue < $1.rawValue }) {
                let value: Int
                if bucketSize == 60, bucketStart / 60 < day.hourlySummary.count {
                    value = day.hourlySummary[bucketStart / 60].value(for: s)
                } else {
                    value = entriesInBucket.reduce(0) { $0 + $1.value(for: s) }
                }

                points.append(ChartDataPoint(
                    bucketStart: bucketStart,
                    bucketEnd: bucketEnd,
                    series: s,
                    value: value,
                    label: label
                ))
            }
        }

        chartData = points
    }

    // MARK: - Summary Helpers

    var totalActiveTime: String {
        guard let day = currentDay else { return "0m" }
        let mins = day.totalActiveMinutes + day.totalEngagedMinutes
        if mins >= 60 {
            return "\(mins / 60)h \(mins % 60)m"
        }
        return "\(mins)m"
    }

    var totalKeystrokes: Int { currentDay?.totalKeyboard ?? 0 }
    var totalClicks: Int { currentDay?.totalClicks ?? 0 }
    var totalScrolls: Int { currentDay?.totalScrolls ?? 0 }
    var totalMovements: Int { currentDay?.totalMovement ?? 0 }
    var totalInputs: Int { currentDay?.totalInputs ?? 0 }

    var averageInputsPerActiveMinute: Int {
        guard let day = currentDay else { return 0 }
        let activeMinutes = day.totalActiveMinutes + day.totalEngagedMinutes
        guard activeMinutes > 0 else { return 0 }
        return day.totalInputs / activeMinutes
    }

    var firstActivityTime: String? {
        guard let first = currentDay?.firstActivity else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: first)
    }

    var lastActivityTime: String? {
        guard let last = currentDay?.lastActivity else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: last)
    }

    var displayDateString: String {
        if isToday { return "Today" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedDate)
    }
}
