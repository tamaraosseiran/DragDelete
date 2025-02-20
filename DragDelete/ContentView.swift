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
        // First row
        HomeScreenItem(name: "Calendar", imageName: "GoogleCalendar"),
        HomeScreenItem(name: "Safari", imageName: "safari"),
        HomeScreenItem(name: "Flighty", imageName: "flighty"),
        HomeScreenItem(name: "Instagram", imageName: "instagram"),
        // Second row
        HomeScreenItem(name: "Find My", imageName: "findmy"),
        HomeScreenItem(name: "Facebook", imageName: "facebook"),
        HomeScreenItem(name: "Messenger", imageName: "messenger"),
        HomeScreenItem(name: "ChatGPT", imageName: "chatgpt"),
        // Third row
        HomeScreenItem(name: "Spotify", imageName: "spotify"),
        HomeScreenItem(name: "TV", imageName: "tv")
    ]
    
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging = false
    @State private var collectedItems = Set<UUID>()
    @State private var showTrashZone = false
    
    // Updated to flexible columns for adaptive spacing
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 15), count: 4)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with proper stretching
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
                                    isCollected: collectedItems.contains(item.id)
                                )
                                .frame(maxWidth: .infinity)
                                .overlay(
                                    GeometryReader { itemGeometry in
                                        Color.clear.onAppear {
                                            if let index = items.firstIndex(where: { $0.id == item.id }) {
                                                items[index].position = CGPoint(
                                                    x: itemGeometry.frame(in: .global).midX,
                                                    y: itemGeometry.frame(in: .global).midY
                                                )
                                            }
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.top, 30)
                        .padding(.horizontal, 10) // Reduced horizontal padding
                    }
                    
                    Spacer()
                    
                    // Bottom container for search and dock
                    VStack(spacing: 6) {
                        Spacer() // Pushes search and dock to the bottom

                        // Search pill - Corrected positioning & size
                        Button(action: {
                            // Define the search action here
                            print("Search button tapped")
                        }) {
                            HStack(spacing: 4) { // Tighter space between icon and text
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)

                                Text("Search")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 14) // Horizontal padding for capsule
                            .padding(.vertical, 12)    // Vertical padding for capsule
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.25))
                            )
                        }
                        .buttonStyle(PlainButtonStyle()) // Removes default button styling
                        .fixedSize() // Ensures button hugs content width
                        .padding(.bottom, 12) // Position closer to the dock


                        // Dock with exact positioning, padding, and corner radius
                        ZStack {
                            RoundedRectangle(cornerRadius: 38)
                                .fill(.ultraThinMaterial)
                                .frame(height: 96)
                                .padding(.horizontal, 16) // Ensures dock is 12px from sides
                                .shadow(radius: 5)

                            HStack(spacing: 24) {
                                ForEach(["phone", "safari", "messages", "mail"], id: \.self) { icon in
                                    DockIcon(imageName: icon)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                        .padding(.bottom, 20) // Dock sits 12px from the bottom
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom) // Forces dock to bottom
                    .ignoresSafeArea(.all, edges: .bottom) // Ignores safe area at bottom



                }
                
                // Collection indicator
                if isDragging {
                    Circle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .position(dragLocation)
                }
                
                // Trash zone
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
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        dragLocation = value.location
                        
                        // Check for items to collect
                        for item in items {
                            let distance = sqrt(
                                pow(dragLocation.x - item.position.x, 2) +
                                pow(dragLocation.y - item.position.y, 2)
                            )
                            
                            if distance < 35 && !collectedItems.contains(item.id) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    collectedItems.insert(item.id)
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                }
                            }
                        }
                        
                        if !collectedItems.isEmpty {
                            withAnimation {
                                showTrashZone = true
                            }
                        }
                    }
                    .onEnded { value in
                        isDragging = false
                        
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
    
    var body: some View {
        VStack(spacing: 6) {
            Image(item.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 65, height: 65) // Adjusted size
                .cornerRadius(12)
            
            Text(item.name)
                .font(.system(size: 12))
                .foregroundStyle(.white)
        }
        .opacity(isCollected ? 0.6 : 1.0)
        .scaleEffect(isCollected ? 0.8 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCollected)
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
