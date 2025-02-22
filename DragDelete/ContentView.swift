import SwiftUI

struct HomeScreenItem: Identifiable {
    let id = UUID()
    let name: String
    let imageName: String
    var position: CGPoint = .zero
    var isCollected = false
}

struct HomeScreenView: View {
    @State private var items: [HomeScreenItem] = [
        HomeScreenItem(name: "Calendar", imageName: "GoogleCalendar"),
        HomeScreenItem(name: "Safari", imageName: "safari"),
        HomeScreenItem(name: "Flighty", imageName: "flighty"),
        HomeScreenItem(name: "Instagram", imageName: "instagram"),
        HomeScreenItem(name: "Find My", imageName: "findmy"),
        HomeScreenItem(name: "Facebook", imageName: "facebook"),
        HomeScreenItem(name: "Messenger", imageName: "messenger"),
        HomeScreenItem(name: "ChatGPT", imageName: "chatgpt"),
        HomeScreenItem(name: "Spotify", imageName: "spotify"),
        HomeScreenItem(name: "TV", imageName: "tv")
    ]
    
    @State private var isEditMode = false
    @State private var dragLocation: CGPoint = .zero
    @State private var collectedItems = Set<UUID>()
    @State private var showTrashZone = false
    @State private var isDragging = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 15), count: 4)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        Image("background")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .edgesIgnoringSafeArea(.all)
                    )

                VStack(spacing: 0) {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(items) { item in
                                AppIconView(
                                    item: item,
                                    isCollected: collectedItems.contains(item.id),
                                    isEditMode: isEditMode
                                )
                                .onLongPressGesture(minimumDuration: 0.5) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        isEditMode = true
                                    }
                                }
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            isDragging = true
                                            dragLocation = value.location
                                            if isEditMode {
                                                collectItem(at: value.location)
                                            }
                                        }
                                        .onEnded { value in
                                            isDragging = false
                                            if !collectedItems.isEmpty {
                                                withAnimation {
                                                    showTrashZone = true
                                                }
                                            }
                                            if value.location.y > UIScreen.main.bounds.height - 150 && !collectedItems.isEmpty {
                                                deleteCollectedItems()
                                            } else {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    collectedItems.removeAll()
                                                    showTrashZone = false
                                                }
                                            }
                                        }
                                )
                            }
                        }
                        .padding(.top, 30)
                        .padding(.horizontal, 30)
                    }

                    Spacer()

                    // Bottom container for search and dock
                    VStack(spacing: 6) {
                        Spacer()

                        // Search pill
                        Button(action: {}) {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 13))
                                Text("Search")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(20)
                        }
                        .padding(.bottom, 16)

                        // Dock
                        ZStack {
                            RoundedRectangle(cornerRadius: 38)
                                .fill(.ultraThinMaterial)
                                .frame(height: 96)
                                .padding(.horizontal, 16)
                                .shadow(radius: 5)

                            HStack(spacing: 24) {
                                ForEach(["phone", "safari", "messages", "mail"], id: \.self) { icon in
                                    DockIcon(imageName: icon)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                        .padding(.bottom, 20)
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(.all, edges: .bottom)
                }

                if showTrashZone {
                    VStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(.ultraThinMaterial)
                                .frame(width: 200, height: 85)

                            VStack(spacing: 4) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.red)
                                Text("Drop to Remove")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .offset(y: -50)
                        .transition(.move(edge: .bottom))
                    }
                }
            }
            // Add tap gesture to exit edit mode
            .contentShape(Rectangle())
            .onTapGesture {
                if isEditMode {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isEditMode = false
                    }
                }
            }
        }
    }

    private func collectItem(at location: CGPoint) {
        for item in items {
            let distance = sqrt(pow(location.x - item.position.x, 2) + pow(location.y - item.position.y, 2))
            if distance < 40 && !collectedItems.contains(item.id) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    collectedItems.insert(item.id)
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
        }
    }

    private func deleteCollectedItems() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            items.removeAll { collectedItems.contains($0.id) }
            collectedItems.removeAll()
            showTrashZone = false
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}

struct AppIconView: View {
    let item: HomeScreenItem
    let isCollected: Bool
    let isEditMode: Bool
    @State private var wiggle = false
    @State private var wiggleOffset: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                Image(item.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .cornerRadius(12)
                
                if isEditMode {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.7))
                            .frame(width: 22, height: 22)
                        
                        Image(systemName: "minus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                    }
                    .offset(x: -8, y: -8)
                }
            }
            
            Text(item.name)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .rotationEffect(.degrees(isEditMode ? (wiggle ? 1.5 : -1.5) : 0))  // Normal state stays at 0
        .onChange(of: isEditMode) { oldValue, newValue in
            if newValue {
                withAnimation(Animation.easeInOut(duration: 0.11)
                    .repeatForever(autoreverses: true)
                    .delay(Double.random(in: 0...0.03))) {
                    wiggle = true
                }
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    wiggle = false
                }
            }
        }
    }
}

struct DockIcon: View {
    let imageName: String

    var body: some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 60, height: 60)
            .cornerRadius(12)
    }
}

struct HomeScreenView_Previews: PreviewProvider {
    static var previews: some View {
        HomeScreenView()
    }
}
