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
    @State private var previousFingerLocation = CGPoint.zero
    @State private var dragVelocity = CGVector.zero
    @State private var appPositions: [UUID: CGPoint] = [:]
    @State private var appFrames: [UUID: CGRect] = [:]
    @State private var stackOffsets: [UUID: CGPoint] = [:]
    @State private var collectAnimation: UUID?
    @State private var lastUpdateTime = Date()
    @State private var particlePositions: [CGPoint] = []
    @State private var particleColors: [Color] = []
    @State private var particleOpacities: [Double] = []
    @State private var particleSizes: [CGFloat] = []
    @State private var showParticles = false
    @State private var deletingItems = false
    @State private var itemsFallingInTrash = false
    @State private var itemsFallingProgress: CGFloat = 0
    @State private var trashBounceScale: CGFloat = 1.0
    @State private var trashPosition: CGPoint = .zero
    @State private var trashSize: CGSize = .zero
    @State private var flyAwayOffsets: [UUID: (CGPoint, Double, Double)] = [:]
    @State private var itemsInTrash: Set<UUID> = []
    @State private var showItemsInTrash = false
    @State private var throwDuration: CGFloat = 0.5
    @State private var throwFactor: CGFloat = 1.0
    @State private var showPoofEffect = false
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 15), count: 4)
    
    func updateStackOffsets() {
        // Calculate time delta for smooth physics
        let now = Date()
        let deltaTime = now.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = now
        
        // Calculate movement vector
        let dx = (fingerLocation.x - previousFingerLocation.x) / CGFloat(max(deltaTime * 20, 0.01))
        let dy = (fingerLocation.y - previousFingerLocation.y) / CGFloat(max(deltaTime * 20, 0.01))
        
        // Update velocity with smoother damping
        dragVelocity = CGVector(
            dx: dragVelocity.dx * 0.85 + dx * 0.15,
            dy: dragVelocity.dy * 0.85 + dy * 0.15
        )
        
        // Get velocity magnitude
        let magnitude = hypot(dragVelocity.dx, dragVelocity.dy)
        
        // Set primary item offset to zero
        if let primaryID = draggedItem?.id {
            stackOffsets[primaryID] = .zero
        }
        
        // Update secondary items
        var index = 0
        for id in collectedItems.sorted() {
            if id == draggedItem?.id { continue }
            
            // Base perfect alignment offset (always maintain this)
            let baseOffset = CGFloat(index + 1) * 3.0
            
            // Add trailing effect only if there's significant movement
            if magnitude > 2.0 {
                // Calculate normalized direction
                let normalizedDx = dragVelocity.dx / magnitude
                let normalizedDy = dragVelocity.dy / magnitude
                
                // Trailing effect (more subtle)
                let trailMagnitude = min(magnitude * 0.03, 0.8) * CGFloat(index + 1)
                
                // Calculate new position - blend base alignment with trailing
                stackOffsets[id] = CGPoint(
                    x: baseOffset - normalizedDx * trailMagnitude * 5.0,
                    y: baseOffset - normalizedDy * trailMagnitude * 5.0
                )
            } else {
                // Default to perfect alignment when not moving quickly
                stackOffsets[id] = CGPoint(x: baseOffset, y: baseOffset)
            }
            
            index += 1
        }
        
        previousFingerLocation = fingerLocation
    }
    
    func checkCollision() {
        for (id, position) in appPositions {
            // Skip already collected items
            if collectedItems.contains(id) { continue }
            
            // Skip dragged item
            if id == draggedItem?.id { continue }
            
            // Simple distance check - very generous (80pt radius)
            let distance = hypot(
                fingerLocation.x - position.x,
                fingerLocation.y - position.y
            )
            
            // If within collection radius
            if distance < 80 {
                collectedItems.insert(id)
                collectAnimation = id
                
                // Haptic feedback
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                
                // Scale feedback intensity based on collection count
                if collectedItems.count % 3 == 0 {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        }
    }
    
    func generateParticles(at position: CGPoint, count: Int = 20) {
        // Initialize particle arrays
        particlePositions = []
        particleColors = []
        particleOpacities = []
        particleSizes = []
        
        for _ in 0..<count {
            // Generate particles in a circular pattern
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 5...25)
            let particlePosition = CGPoint(
                x: position.x + cos(angle) * distance,
                y: position.y + sin(angle) * distance
            )
            
            particlePositions.append(particlePosition)
            
            // Random color: whites, grays, and accent colors
            let colorChoice = Int.random(in: 0...10)
            if colorChoice < 5 {
                particleColors.append(Color.white.opacity(0.8))
            } else if colorChoice < 8 {
                particleColors.append(Color.gray.opacity(0.7))
            } else {
                particleColors.append(Color.blue.opacity(0.6))
            }
            
            particleOpacities.append(Double.random(in: 0.5...1.0))
            particleSizes.append(CGFloat.random(in: 2...5))
        }
        
        showParticles = true
        
        // Auto-hide particles after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                showParticles = false
            }
        }
    }
    
    func particleView(at index: Int) -> some View {
        let position = particlePositions[index]
        let color = particleColors[index]
        let size = particleSizes[index]
        let opacity = particleOpacities[index]
        
        return Circle()
            .fill(color)
            .frame(width: size, height: size)
            .opacity(opacity)
            .position(position)
            .transition(.scale.combined(with: .opacity))
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
                                .scaleEffect(collectAnimation == item.id ? 1.1 : 1.0)
                                .animation(.spring(response: 0.3), value: collectAnimation == item.id)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.onAppear {
                                            let frame = geo.frame(in: .global)
                                            appPositions[item.id] = CGPoint(x: frame.midX, y: frame.midY)
                                            appFrames[item.id] = frame
                                        }
                                    }
                                )
                                .overlay(
                                    // Black semi-transparent overlay when near finger
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.black.opacity(0.3))
                                            .frame(width: 75, height: 90)
                                            .opacity(
                                                isDragging && 
                                                !collectedItems.contains(item.id) && 
                                                distance(from: fingerLocation, to: appPositions[item.id] ?? .zero) < 100 ? 
                                                1 : 0
                                            )
                                    }
                                )
                                .onChange(of: collectAnimation) { oldValue, newValue in
                                    if newValue == item.id {
                                        // Reset collection animation after a delay
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            if collectAnimation == item.id {
                                                collectAnimation = nil
                                            }
                                        }
                                    }
                                }
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
                                                previousFingerLocation = fingerLocation
                                                lastUpdateTime = Date()
                                                
                                                withAnimation(.spring(response: 0.3)) {
                                                    showTrashZone = true
                                                }
                                                
                                                // Initial haptic feedback
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                
                                                // When drag begins, prepare for potential deletion animation
                                                for id in collectedItems {
                                                    // Calculate a unique angle for each item to fan out
                                                    let angle = Double.random(in: -0.5...0.5)
                                                    
                                                    // Calculate rotation - alternating directions and speeds
                                                    let rotation = Double.random(in: -360...360)
                                                    
                                                    // Store the animation parameters (empty CGPoint will be filled during deletion)
                                                    flyAwayOffsets[id] = (.zero, angle, rotation)
                                                }
                                            }
                                            
                                            // Update stack offsets based on movement
                                            updateStackOffsets()
                                            
                                            // Check for collecting other apps
                                            checkCollision()
                                            
                                            // Check if over trash with magnetic effect
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
                                                // EXPLICITLY show the poof effect
                                                withAnimation {
                                                    showPoofEffect = true
                                                }
                                                
                                                // Make trash respond
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                                    // Your trash animation code
                                                }
                                                
                                                // Add debug print to verify it's being triggered
                                                print("Showing poof effect!")
                                                
                                                // Hide poof after delay and delete items
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                                    withAnimation {
                                                        // Delete items
                                                        items.removeAll { collectedItems.contains($0.id) }
                                                        
                                                        // Reset states
                                                        isDragging = false
                                                        draggedItem = nil
                                                        collectedItems.removeAll()
                                                        isOverTrash = false
                                                    }
                                                    
                                                    // Keep poof visible a bit longer
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                        withAnimation {
                                                            showPoofEffect = false
                                                        }
                                                        print("Hiding poof effect")
                                                    }
                                                }
                                            } else {
                                                // Not over trash, just reset
                                                withAnimation {
                                                    isDragging = false
                                                    draggedItem = nil
                                                    collectedItems.removeAll()
                                                    isOverTrash = false
                                                }
                                            }
                                        }
                                )
                            }
                        }
                        .padding(.top, 30)
                        .padding(.horizontal, 45)
                    }
                    
                    Spacer()
                    
                    // floating dock
                    if isEditMode {
                        VStack {
                            Spacer()
                            
                            // Floating dock with improved visuals
                            ZStack {
                                // Background that adapts to phone's background colors
                                RoundedRectangle(cornerRadius: 30) // More rounded corners
                                    .fill(Material.ultraThinMaterial) // Better material that adapts to background
                                    .overlay(
                                        // Dark overlay to make it a darker version of background
                                        RoundedRectangle(cornerRadius: 30)
                                            .fill(Color.black.opacity(0.3))
                                    )
                                    .overlay(
                                        // Subtle border for definition
                                        RoundedRectangle(cornerRadius: 30)
                                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                                    )
                                    .frame(width: UIScreen.main.bounds.width * 0.85, height: 105)
                                    .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 5)
                                
                                // Trash icon
                                Image("trashcan")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 60)
                                    .opacity(isOverTrash ? 1.0 : 0.9)
                                    .scaleEffect(isOverTrash ? 1.15 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: isOverTrash)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 25) // Lower position (reduced from 40)
                            .background(
                                GeometryReader { geometry -> Color in
                                    DispatchQueue.main.async {
                                        trashPosition = CGPoint(
                                            x: geometry.frame(in: .global).midX,
                                            y: geometry.frame(in: .global).midY
                                        )
                                        trashSize = CGSize(
                                            width: UIScreen.main.bounds.width * 0.85,
                                            height: 105)
                                    }
                                    return Color.clear
                                }
                            )
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(100)
                    }
                }
                
                // Card stack with physics-based trailing but maintaining alignment
                if isDragging {
                    ZStack {
                        // Draw collected items in reverse order for proper stacking
                        ForEach(Array(collectedItems.sorted().reversed()), id: \.self) { itemID in
                            if let index = items.firstIndex(where: { $0.id == itemID }) {
                                let item = items[index]
                                let isPrimary = itemID == draggedItem?.id
                                let offset = stackOffsets[itemID] ?? .zero
                                
                                Image(item.imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.2), radius: 3, x: 1, y: 2)
                                    .offset(x: offset.x, y: offset.y)
                                    .zIndex(isPrimary ? 100 : Double(collectedItems.count - Array(collectedItems).sorted().firstIndex(of: itemID)!))
                            }
                        }
                    }
                    .position(fingerLocation)
                }
                
                // Render particles
                if showParticles {
                    ForEach(0..<particlePositions.count, id: \.self) { index in
                        particleView(at: index)
                    }
                }
                
                // Add this at the END of your main ZStack to ensure it's on top
                if showPoofEffect {
                    PoofEffect()
                        .frame(width: 200, height: 200)
                        .position(x: trashPosition.x, y: trashPosition.y - 60)
                        .zIndex(1000) // Very high z-index to ensure it's on top
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isEditMode {
                    withAnimation {
                        isEditMode = false
                    }
                }
            }
            .onLongPressGesture {
                withAnimation {
                    isEditMode = true
                }
            }
        }
    }
    
    // Helper function to calculate distance between points
    func distance(from point1: CGPoint, to point2: CGPoint) -> CGFloat {
        return hypot(point1.x - point2.x, point1.y - point2.y)
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

struct PoofEffect: View {
    // Make the poof more visible for debugging
    @State private var scale: CGFloat = 0.2
    @State private var opacity: Double = 1.0
    
    var body: some View {
        ZStack {
            ForEach(0..<8) { i in
                Circle() // Simpler shape for debugging
                    .fill(Color.white.opacity(opacity))
                    .frame(width: 40, height: 40)
                    .offset(
                        x: CGFloat.random(in: -30...30),
                        y: CGFloat.random(in: -30...30)
                    )
            }
        }
        .scaleEffect(scale)
        .onAppear {
            print("Poof effect appeared!")
            
            withAnimation(.easeOut(duration: 0.25)) {
                scale = 1.2
            }
            
            withAnimation(.easeInOut(duration: 0.7).delay(0.1)) {
                opacity = 0
                scale = 2.0
            }
        }
    }
}

