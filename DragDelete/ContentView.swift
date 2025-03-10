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
    @State private var isDragging = false
    @State private var draggedItem: HomeScreenItem?
    @State private var collectedItems = Set<UUID>()
    @State private var showTrashZone = false
    @State private var isOverTrash = false
    @State private var fingerLocation = CGPoint.zero
    @State private var appPositions: [UUID: CGPoint] = [:]
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 15), count: 4)
    
    func checkCollision() {
        for (id, position) in appPositions {
            // Skip already collected items
            if collectedItems.contains(id) { continue }
            
            // Skip dragged item
            if id == draggedItem?.id { continue }
            
            // Simple distance check - very generous (100pt radius)
            let distance = hypot(
                fingerLocation.x - position.x,
                fingerLocation.y - position.y
            )
            
            // If within collection radius
            if distance < 100 {
                collectedItems.insert(id)
                // Optional haptic feedback
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                    .overlay(
                        Image("background")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .edgesIgnoringSafeArea(.all)
                    )

                VStack(spacing: 0) {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(items.indices, id: \.self) { index in
                                let item = items[index]
                                
                                AppIconView(
                                    item: item,
                                    isCollected: false,
                                    isEditMode: isEditMode
                                )
                                .opacity(isDragging && collectedItems.contains(item.id) ? 0 : 1)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.onAppear {
                                            let center = CGPoint(
                                                x: geo.frame(in: .global).midX,
                                                y: geo.frame(in: .global).midY
                                            )
                                            appPositions[item.id] = center
                                        }
                                    }
                                )
                                .gesture(
                                    DragGesture()
                                        .onChanged { gesture in
                                            guard isEditMode else { return }
                                            
                                            // Update finger location
                                            fingerLocation = gesture.location
                                            
                                            // Start dragging
                                            if !isDragging {
                                                isDragging = true
                                                draggedItem = item
                                                collectedItems.insert(item.id)
                                                showTrashZone = true
                                            }
                                            
                                            // Check for collecting other apps
                                            checkCollision()
                                            
                                            // Check if over trash
                                            let trashFrame = CGRect(
                                                x: 0,
                                                y: geometry.size.height - 100,
                                                width: geometry.size.width,
                                                height: 100
                                            )
                                            isOverTrash = trashFrame.contains(gesture.location)
                                        }
                                        .onEnded { _ in
                                            guard isEditMode, isDragging else { return }
                                            
                                            if isOverTrash && !collectedItems.isEmpty {
                                                items.removeAll { collectedItems.contains($0.id) }
                                            }
                                            
                                            // Reset state
                                            isDragging = false
                                            draggedItem = nil
                                            collectedItems.removeAll()
                                            showTrashZone = false
                                            isOverTrash = false
                                        }
                                )
                            }
                        }
                        .padding(.top, 30)
                        .padding(.horizontal, 45)
                    }
                    
                    Spacer()
                    
                    // Trash zone
                    if showTrashZone {
                        ZStack {
                            Capsule()
                                .fill(Color.gray.opacity(0.7))
                                .frame(height: 70)
                            
                            Image(systemName: "trash")
                                .font(.system(size: isOverTrash ? 35 : 25))
                                .foregroundColor(.white)
                                .scaleEffect(isOverTrash ? 1.3 : 1.0)
                                .animation(.spring(response: 0.3), value: isOverTrash)
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 20)
                    }
                }
                
                // Card stack
                if isDragging, let _ = draggedItem {
                    ZStack {
                        // Draw collected items
                        ForEach(Array(collectedItems).filter { $0 != draggedItem?.id }, id: \.self) { itemID in
                            if let index = items.firstIndex(where: { $0.id == itemID }) {
                                let item = items[index]
                                let stackIndex = Array(collectedItems).firstIndex(of: itemID) ?? 0
                                let offset = CGFloat(stackIndex) * 3.0
                                
                                Image(item.imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(12)
                                    .offset(x: offset, y: offset)
                                    .zIndex(Double(stackIndex))
                            }
                        }
                        
                        // Primary dragged item
                        if let primaryID = draggedItem?.id,
                           let index = items.firstIndex(where: { $0.id == primaryID }) {
                            let item = items[index]
                            
                            Image(item.imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .cornerRadius(12)
                                .zIndex(100) // Always on top
                        }
                    }
                    .position(fingerLocation)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isEditMode {
                    isEditMode = false
                }
            }
            .onLongPressGesture {
                isEditMode = true
            }
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
        .rotationEffect(.degrees(isEditMode ? (wiggle ? 1.3 : -1.3) : 0))  // Normal state stays at 0
        .onChange(of: isEditMode) { oldValue, newValue in
            if newValue {
                withAnimation(Animation.easeInOut(duration: 0.13)
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

