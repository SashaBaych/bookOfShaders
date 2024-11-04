import SwiftUI
import MetalKit
import simd

struct Uniforms {
    var resolution: SIMD2<Float>
    var mouse: SIMD2<Float>
    var time: Float
    private var _padding: Float = 0
    
    init(resolution: SIMD2<Float>, mouse: SIMD2<Float>, time: Float) {
        self.resolution = resolution
        self.mouse = mouse
        self.time = time
        self._padding = 0
    }
}

struct IkedaView: UIViewRepresentable {
    @State private var location: CGPoint = .zero
    
    class Coordinator: NSObject, MTKViewDelegate {
        var parent: IkedaView
        var device: MTLDevice
        var commandQueue: MTLCommandQueue
        var pipelineState: MTLRenderPipelineState
        var vertexBuffer: MTLBuffer
        var startTime: Date
        var uniformsBuffer: MTLBuffer?
        var frameCounter: Int = 0
        
        init(_ parent: IkedaView) {
            self.parent = parent
            print("Initializing Metal setup...")
            
            guard let device = MTLCreateSystemDefaultDevice(),
                  let commandQueue = device.makeCommandQueue() else {
                fatalError("Metal initialization failed")
            }
            
            self.device = device
            self.commandQueue = commandQueue
            print("Device: \(device.name)")
            
            let vertices: [Float] = [
                -1, -1, 0, 1,  0, 0,
                 1, -1, 0, 1,  1, 0,
                -1,  1, 0, 1,  0, 1,
                 1,  1, 0, 1,  1, 1
            ]
            
            vertexBuffer = device.makeBuffer(bytes: vertices,
                                           length: vertices.count * MemoryLayout<Float>.size,
                                           options: [])!
            print("Vertex buffer created")
            
            let uniformsSize = MemoryLayout<Uniforms>.size
            uniformsBuffer = device.makeBuffer(length: uniformsSize,
                                             options: [.storageModeShared])
            print("Uniforms buffer created with size: \(uniformsSize)")
            
            do {
                guard let library = device.makeDefaultLibrary() else {
                    print("Failed to create Metal library")
                    fatalError("Failed to create Metal library")
                }
                print("Metal library created successfully")
                
                guard let vertexFunction = library.makeFunction(name: "vertex_shader") else {
                    print("Failed to create vertex function")
                    fatalError("Failed to create vertex function")
                }
                print("Vertex shader function created successfully")
                
                guard let fragmentFunction = library.makeFunction(name: "fragment_shader") else {
                    print("Failed to create fragment function")
                    fatalError("Failed to create fragment function")
                }
                print("Fragment shader function created successfully")
                
                let pipelineDescriptor = MTLRenderPipelineDescriptor()
                pipelineDescriptor.vertexFunction = vertexFunction
                pipelineDescriptor.fragmentFunction = fragmentFunction
                pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
                
                let vertexDescriptor = MTLVertexDescriptor()
                vertexDescriptor.attributes[0].format = .float4
                vertexDescriptor.attributes[0].offset = 0
                vertexDescriptor.attributes[0].bufferIndex = 0
                vertexDescriptor.attributes[1].format = .float2
                vertexDescriptor.attributes[1].offset = 16
                vertexDescriptor.attributes[1].bufferIndex = 0
                vertexDescriptor.layouts[0].stride = 24
                
                pipelineDescriptor.vertexDescriptor = vertexDescriptor
                
                self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
                print("Pipeline state created successfully")
            } catch {
                print("Failed to create pipeline state: \(error)")
                fatalError("Failed to create pipeline state: \(error)")
            }
            
            self.startTime = Date()
            print("Metal setup completed successfully")
            
            super.init()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            print("View size changed to: \(size)")
        }
        
        func draw(in view: MTKView) {
            frameCounter += 1
            if frameCounter % 60 == 0 {
                print("Draw called - Frame: \(frameCounter)")
            }
            
            guard let drawable = view.currentDrawable,
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
                  let uniformsBuffer = uniformsBuffer else {
                print("Failed to create required Metal objects")
                return
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            var uniforms = Uniforms(
                resolution: SIMD2<Float>(Float(view.bounds.width), Float(view.bounds.height)),
                mouse: SIMD2<Float>(Float(parent.location.x), Float(parent.location.y)),
                time: Float(elapsed)
            )
            
            if frameCounter % 60 == 0 {
                print("Time: \(elapsed), Resolution: \(uniforms.resolution), Mouse: \(uniforms.mouse)")
            }
            
            let uniformsPtr = uniformsBuffer.contents()
            memcpy(uniformsPtr, &uniforms, MemoryLayout<Uniforms>.size)
            
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: 0)
            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            
            renderEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            parent.location = location
            print("Pan gesture location: \(location)")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> MTKView {
        print("Creating MTKView")
        let mtkView = MTKView()
        mtkView.device = context.coordinator.device
        mtkView.delegate = context.coordinator
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 60
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.drawableSize = mtkView.frame.size
        
        let gesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        mtkView.addGestureRecognizer(gesture)
        
        print("MTKView created and configured")
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        uiView.setNeedsDisplay()
    }
}

struct ContentView: View {
    var body: some View {
        IkedaView()
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
