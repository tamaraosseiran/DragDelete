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
    @State private var collectedItems: Set<UUID> = []
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
    @State private var trashFrame: CGRect = .zero
    @State private var isTrashFull: Bool = false
    
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
                                            
                                            // Check if over trash using the frame
                                            let dragPosition = gesture.location
                                            isOverTrash = trashFrame.contains(dragPosition)
                                        }
                                        .onEnded { value in
                                            if isOverTrash && !collectedItems.isEmpty {
                                                // Very short delay before showing poof (just enough to register the drop)
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                                    withAnimation {
                                                        showPoofEffect = true
                                                    }
                                                    
                                                    // Delete items during the poof animation
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                                        // Delete items as poof is expanding
                                                        items.removeAll { collectedItems.contains($0.id) }
                                                        
                                                        // Reset states
                                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                            isDragging = false
                                                            draggedItem = nil
                                                            collectedItems.removeAll()
                                                            isOverTrash = false
                                                        }
                                                        
                                                        // Let poof complete before hiding
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                            withAnimation {
                                                                showPoofEffect = false
                                                            }
                                                        }
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
                            
                            // Dock container - no poof effect here
                            ZStack {
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(
                                        .ultraThinMaterial
                                        .opacity(0.7)
                                    )
                                    .frame(width: UIScreen.main.bounds.width * 0.82, height: 108)
                                
                                // Trash icon with state
                                if isTrashFull {
                                    Image("trash-full")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 60, height: 60)
                                        .opacity(isOverTrash ? 1.0 : 0.95)
                                        .scaleEffect(isOverTrash ? 1.2 : 1.0)
                                } else {
                                    Image("trashcan")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 60, height: 60)
                                        .opacity(isOverTrash ? 1.0 : 0.95)
                                        .scaleEffect(isOverTrash ? 1.2 : 1.0)
                                }
                            }
                            .padding(.vertical, 24)
                            .padding(.bottom, 20)
                            .frame(maxWidth: .infinity)
                            .background(
                                GeometryReader { geometry -> Color in
                                    DispatchQueue.main.async {
                                        let frame = geometry.frame(in: .global)
                                        trashPosition = CGPoint(
                                            x: frame.midX,
                                            y: frame.midY
                                        )
                                        trashSize = CGSize(
                                            width: UIScreen.main.bounds.width * 0.82,
                                            height: 108
                                        )
                                        
                                        // IMPORTANT: Create a much larger and better positioned hit area
                                        // Move it up significantly and make it taller
                                        trashFrame = CGRect(
                                            x: frame.midX - (frame.width / 2),
                                            // Shift up by 60 points to make the visual center more accurate
                                            y: frame.midY - 60 - (frame.height / 2),
                                            width: frame.width,
                                            // Make the hit area much taller (double height + extra)
                                            height: frame.height * 2 + 40
                                        )
                                    }
                                    return Color.clear
                                }
                            )
                            .overlay(
                                Group {
                                    if isEditMode && false { // Set to true only during development
                                        Rectangle()
                                            .stroke(Color.red, lineWidth: 2)
                                            .frame(
                                                width: trashFrame.width,
                                                height: trashFrame.height
                                            )
                                            .position(
                                                x: trashPosition.x,
                                                y: trashPosition.y - 60 // Match the offset from above
                                            )
                                    }
                                }
                            )
                        }
                        .transition(.opacity)
                        .zIndex(100)
                        .ignoresSafeArea(edges: .bottom)
                    }
                }
                
                // Card stack with physics-based trailing but maintaining alignment
                if isDragging {
                    DraggedItemsView()
                }
                
                // Render particles
                if showParticles {
                    ForEach(0..<particlePositions.count, id: \.self) { index in
                        particleView(at: index)
                    }
                }
                
                // Completely separate poof effect overlay
                if showPoofEffect {
                    PoofEffect()
                        .frame(width: 150, height: 150)
                        .position(x: trashPosition.x, y: trashPosition.y - 50)
                        .zIndex(1000)
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
    
    private func DraggedItemsView() -> some View {
        ZStack {
            // First layer: Draw collected items
            ZStack {
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
            
            // Second layer: Counter badge
            if collectedItems.count > 1 {
                CounterBadgeView(count: collectedItems.count)
                    .offset(x: 25, y: -25)
                    .zIndex(999)
            }
        }
        .position(fingerLocation)
    }
    
    // Updated CounterBadgeView to ensure perfect circle shape
    private func CounterBadgeView(count: Int) -> some View {
        ZStack {
            // Perfect circle with fixed size
            Circle()
                .fill(Color.red)
                .frame(width: 26, height: 26)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            
            // Text centered within the circle
            Text("\(count)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                // Set minimum width to ensure centering
                .frame(minWidth: 20, alignment: .center)
        }
        // Force a fixed frame size regardless of content
        .frame(width: 26, height: 26)
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
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 1.0
    
    var body: some View {
        ZStack {
            ForEach(0..<8) { i in
                Circle()
                    .fill(Color.white.opacity(opacity))
                    .frame(width: 30, height: 30)
                    .offset(
                        x: CGFloat.random(in: -25...25),
                        y: CGFloat.random(in: -25...25)
                    )
            }
        }
        .scaleEffect(scale)
        .onAppear {
            // Quick but not instant initial expansion
            withAnimation(.easeOut(duration: 0.12)) {
                scale = 1.1
            }
            
            // Slightly longer fade for visibility
            withAnimation(.easeInOut(duration: 0.25).delay(0.02)) {
                opacity = 0
                scale = 1.5
            }
        }
    }
}

